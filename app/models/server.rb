require 'logger'
require 'async_exec'
require 'timeout'
require 'base64'

class Server < ActiveRecord::Base

  cattr_accessor :server_online_timeout
  self.server_online_timeout = 600

  belongs_to :server_group
  belongs_to :account
  validates_presence_of :name, :description, :flavor_id, :image_id, :server_group_id, :account_id
  has_many :server_errors
  validates_format_of :name, :with => /^[A-Za-z0-9\-\.]+$/, :message => "Server name must use valid hostname characters (A-Z, a-z, 0-9, dash)."
  validates_length_of :name, :maximum => 255
  validates_length_of :description, :maximum => 255

  attr_accessor :base64_command
  has_one :server_command, :dependent => :destroy, :autosave => true

  attr_accessible :name, :description, :flavor_id, :image_id, :account_id, :base64_command, :gateway, :server_group_id, :cloud_server_id_number

  def self.new_for_type(params)

    image_id = params[:image_id]
    if image_id.nil? then
      image_id = params["image_id"]
    end
    account_id = params[:account_id]
    if account_id.nil? then
      account_id = params["account_id"]
    end

    LinuxServer.new(params)

  end

  validate :handle_validate_on_create, :on => :create
  def handle_validate_on_create

  if self.server_group then
    gateway_count=0
    self.server_group.servers.each do |server|
     gateway_count += 1 if server.gateway
      end
      if gateway_count == 1 and self.gateway then
        errors[:base] << "Server groups may not have more than one gateway Server."
      end
    end

  end

  validate :handle_validate
  def handle_validate

    count=0

    if new_record? then
      count=Server.count(:conditions => ["server_group_id = ? AND name = ?", self.server_group_id, self.name])
    else
      count=Server.count(:conditions => ["server_group_id = ? AND name = ? AND id != ?", self.server_group_id, self.name, self.id])
    end

    if count > 0 then
      errors[:base] << "Server name '#{self.name}' is already used in this server group."
    end

  end

  after_initialize :handle_after_initialize
  def handle_after_initialize
    if new_record? then
      self.historical = false
    end
    @tmp_files=[]
  end

  after_create :handle_after_create
  def handle_after_create
    if base64_command then
      ServerCommand.create(:command => Base64.decode64(base64_command), :server_id => self.attributes["id"])
    end
  end

  def make_historical
    if not self.cloud_server_id_number.nil? then
      delete_cloud_server(self.cloud_server_id_number)
    end
    update_attribute(:historical, true)
  end

  def create_cloud_server

    return if self.status == "Online"
    if self.retry_count >= 3 then
      self.status = "Failed"
      save
      return
    end

    begin

      if capture_pool_server then
        AsyncExec.run_job(ConfigureServer, self.id)
      else
        server_name_prefix=""
        if not ENV['SERVER_NAME_PREFIX'].blank? then
          server_name_prefix=ENV['SERVER_NAME_PREFIX']
        end
        
        conn = self.account_connection

        # Rackspace enforces unique server names. This works around that...
        retry_suffix=self.retry_count > 0 ? "#{rand(10)}-#{self.retry_count}" : "#{rand(10)}"
        server_id, admin_password = conn.create_server("#{server_name_prefix}#{self.name}-#{self.server_group_id}-#{retry_suffix}", self.image_id, self.flavor_id, generate_personalities)

        @tmp_files.each {|f| f.close(true)} #Remove tmp personalities files

        self.cloud_server_id_number = server_id
        #self.admin_password = admin_password
        save!
        AsyncExec.run_job(HarvestIpInfo, self.id)
      end

    rescue Exception => e
      self.retry_count += 1
      self.status = "Pending" # keep status set to pending

      long_error_message=nil
      begin
        long_error_message="#{e.message}: #{e.response_body}"
      rescue
      end

      if e and e.message and long_error_message then
        self.add_error_message("Failed to create cloud server: #{e.message}", long_error_message)
      elsif e and e.message then
        self.add_error_message("Failed to create cloud server: #{e.message}")
      else
        self.add_error_message("Failed to create cloud server.")
      end
      save!
      sleep 10
      AsyncExec.run_job(CreateCloudServer, self.id)

    end

  end

  def harvest_ip_info

    return if self.status == "Online"
    if self.retry_count >= 3 then
      self.status = "Failed"
      save
      return
    end

    timeout = self.server_online_timeout-(Time.now-self.updated_at).to_i
    conn = self.account_connection

    begin

      server = conn.get_server(self.cloud_server_id_number)
      Timeout::timeout(timeout) do
        until server[:public_ip] and server[:private_ip] do
          server = conn.get_server(self.cloud_server_id_number)
          raise "Server in error state." if server[:status] == 'ERROR'
          sleep 1
        end
        self.external_ip_addr = server[:public_ip]
        self.internal_ip_addr = server[:private_ip]
        save!
      end

      AsyncExec.run_job(ConfigureServer, self.id)

    rescue Exception => e
      self.retry_count += 1
      self.status = "Pending" # keep status set to pending

      long_error_message=nil
      begin
        long_error_message="#{e.message}: #{e.response_body}"
      rescue
      end

      if e and e.message and long_error_message then
        self.add_error_message("Failed to obtain IP info: #{e.message}", long_error_message)
      elsif e and e.message then
        self.add_error_message("Failed to obtain IP info: #{e.message}")
      else
        self.add_error_message("Failed to obtain IP info.")
      end
      save!

      if not self.cloud_server_id_number.nil? then
        delete_cloud_server(self.cloud_server_id_number)
      end

      sleep 10
      AsyncExec.run_job(CreateCloudServer, self.id)

    end

  end


  def delete_cloud_server(cloud_server_id)
    deleted=false
    retry_count=0
    until deleted or retry_count >= 3 do
      begin
        retry_count += 1
        self.account_connection.destroy_server(cloud_server_id)
        deleted = true
      rescue
        # ignore all exceptions on delete
      end
    end
  end

  def rebuild
    begin

      Timeout::timeout(30) do
        gw_server=Server.find(:first, :conditions => ["server_group_id = ? AND gateway = ?", self.server_group_id, true])
        %x{
          ssh -T -i #{self.server_group.ssh_key_basepath} root@#{gw_server.external_ip_addr} sed "/^#{self.name}.*/d" -i .ssh/known_hosts
        }
      end

      # NOTE: Cloud Servers v1.0 rebuild doesn't support personalities so
      # we do a delete and create instead.
      if not self.cloud_server_id_number.nil? then
        delete_cloud_server(self.cloud_server_id_number)
      end
      sleep 10
      AsyncExec.run_job(CreateCloudServer, self.id)
    rescue Exception => e
      fail_and_raise "Failed to rebuild cloud server.", e
    end

  end

  def account_connection
    acct=Account.find(self.account_id)
    acct.get_connection
  end

  def add_error_message(message, long_error_message=message)
    self.error_message=message
    self.server_errors << ServerError.new(:error_message => long_error_message, :cloud_server_id_number => self.cloud_server_id_number)
  end

  # set failure status, record error message and then raise an exception
  def fail_and_raise(message, exception=nil)
    self.status = "Failed"
    if exception.nil? then
      self.add_error_message(message)
      save
      raise message
    else
      begin
        self.add_error_message("#{message}: #{exception.message}")
        save
      rescue
        self.add_error_message(message)
        save
      end
      raise exception
    end
  end

end
