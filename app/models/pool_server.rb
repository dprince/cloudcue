require 'util/tmp_dir'
require 'util/ssh_keygen'
require 'tempfile'
require 'timeout'

class PoolServer < ActiveRecord::Base
  validates_presence_of :flavor_ref, :image_ref, :pool_id, :account_id, :status
  belongs_to :pool
  belongs_to :account

  include Util::SshKeygen

  cattr_accessor :server_online_timeout
  self.server_online_timeout = 800

  attr_accessible :pool_id, :flavor_ref, :image_ref, :account_id, :cloud_server_id_number

  after_initialize :handle_after_initialize
  def handle_after_initialize
      @tmp_files=[]
  end

  def create_pool_server

    begin
      server_name_prefix=""
      if not ENV['SERVER_NAME_PREFIX'].blank? then
        server_name_prefix=ENV['SERVER_NAME_PREFIX']
      end
      
      conn = self.account.get_connection

      keypair = generate_keypair
      self.private_key = IO.read(keypair[:private_key])
      personalities = generate_personalities(keypair[:public_key])

      server_id, admin_password = conn.create_server("#{server_name_prefix}pool#{self.id}", self.image_ref, self.flavor_ref, personalities)

      self.cloud_server_id = server_id
      save!

      server = conn.get_server(server_id)
      Timeout::timeout(self.server_online_timeout) do
        until server[:public_ip] and server[:private_ip] do
          server = conn.get_server(server_id)
          raise "Server in error state." if server[:status] == 'ERROR'
          sleep 1
        end

        ActiveRecord::Base.connection_handler.verify_active_connections!
        self.external_ip_addr = server[:public_ip]
        self.internal_ip_addr = server[:private_ip]
        save!
      end

      loop_until_server_online(keypair[:private_key])
      ActiveRecord::Base.connection_handler.verify_active_connections!

      @tmp_files.each {|f| f.close(true)} #Remove tmp personalities files

      self.status = "Online"
      save!

    rescue Exception => e

      self.status = "Failed"
      begin 
        make_historical
      rescue
      end

      long_error_message=nil
      begin
        long_error_message="#{e.message}: #{e.response_body}"
      rescue
      end

      if long_error_message then
        self.error_message = "Failed to create server: #{long_error_message}"
      elsif e and e.message then
        self.error_message = "Failed to create server: #{e.message}"
      else
        self.error_message = "Failed to create cloud server."
      end

      save!

    end

  end

  # method to block until a server is online
  def loop_until_server_online(private_key)
    conn = self.account.get_connection

    error_message = "Failed to build server."

    timeout = self.server_online_timeout-(Time.now-self.updated_at).to_i
    timeout = 360 if timeout < 360

    begin
      Timeout::timeout(timeout) do

        # poll the server until progress is 100%
        server = conn.get_server(self.cloud_server_id)
        until server[:progress] == 100 and server[:status] == "ACTIVE" do
          server = conn.get_server(self.cloud_server_id)
          raise "Server in error state." if server[:status] == 'ERROR'
          sleep 1
        end

        error_message="Failed to ssh to the node."  
        if ! system(%{

            COUNT=0
            while ! ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -T -i #{private_key} root@#{server[:public_ip]} /bin/true > /dev/null 2>&1; do
              if (($COUNT > 23)); then
                exit 1
              fi
              ((COUNT++))
              sleep 15
            done
            exit 0

        }) then
          raise error_message
        end

      end
    end

  end

  def generate_keypair

    key_dir = Util::TmpDir.tmp_dir()
    key_base_path = File.join(key_dir, 'key')
    generate_ssh_keypair(key_base_path)

    {
      :private_key => key_base_path,
      :public_key => key_base_path+".pub"
    }

  end

  def delete_cloud_server(cloud_server_id)
    deleted=false
    retry_count=0
    until deleted or retry_count >= 3 do
      begin
        retry_count += 1
        self.account.get_connection.destroy_server(cloud_server_id)
        deleted = true
      rescue
      # ignore all exceptions on delete
      end
    end
  end

  def make_historical
    update_attribute(:historical, true)
    if not self.cloud_server_id.nil? then
      delete_cloud_server(self.cloud_server_id)
    end
  end

  # Generates a personalities hash suitable for use with bindings
  def generate_personalities(public_key)
    [{'contents' => IO.read(public_key), 'path' => '/root/.ssh/authorized_keys'}]
  end

end
