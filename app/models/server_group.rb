require 'util/ssh_keygen'

class ServerGroup < ActiveRecord::Base

  include Util::SshKeygen

  validates_presence_of :name, :domain_name, :description, :owner_name, :user_id
  validates_length_of :name, :maximum => 255
  validates_length_of :description, :maximum => 255
  validates_length_of :owner_name, :maximum => 255
  validates_length_of :domain_name, :maximum => 255
  has_many :servers
  accepts_nested_attributes_for :servers, :update_only => true
  has_many :ssh_public_keys, :dependent => :destroy
  belongs_to :user
  has_one :ssh_keypair

  validates_associated :servers
  validates_associated :ssh_public_keys

  attr_accessible :name, :description, :flavor_id, :image_id, :domain_name, :owner_name, :user_id, :servers_attributes

    after_initialize :handle_after_initialize
  def handle_after_initialize
    if new_record? then
      self.historical = false
    end
  end

  after_create :handle_after_create
  def handle_after_create
    generate_ssh_keypair(ssh_key_basepath)
    keypair_params={
      :server_group_id => self.attributes["id"],
      :private_key => IO.read(ssh_key_basepath),
      :public_key => IO.read(ssh_key_basepath+".pub")
    }
    self.ssh_keypair=SshKeypair.create(keypair_params)
  end

  before_destroy :handle_before_destroy
  def handle_before_destroy
    FileUtils.rm_rf(self.ssh_key_basepath)
    FileUtils.rm_rf(self.ssh_key_basepath+".pub")
  end

  def ssh_key_basepath
    path=File.join(Rails.root, 'tmp', 'ssh_keys', Rails.env, self.id.to_s)
    kp=self.ssh_keypair  
    if not kp.nil? then
      # write ssh keys to disk from the DB if they don't already exist
      if not File.exists?(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w') do |f|
          f.write(kp.private_key)
          f.chmod(0600)
        end
      end
      if not File.exists?(path+".pub")
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path+".pub", 'w') {|f| f.write(kp.public_key)}
      end
    end
    path
  end

  def make_historical
    self.servers.each do |server|
      server.make_historical
    end
  end

  def configure_ssh_and_hosts(pkey_path=self.ssh_key_basepath)

    gateway = self.servers.select { |s| s.gateway }[0]
    domain = self.domain_name

    guest_names = ""
    if self.servers.size > 1 then
      guests = self.servers.select { |s| s if not s.gateway }
      guest_names = guests.collect { |s| "#{s.name}" }.join(" ")
    end

    hosts_file_data = "127.0.0.1\tlocalhost localhost.localdomain\n"
    self.servers.each do |server|
      hosts_file_data += "#{server.internal_ip_addr}\t#{server.name}\t#{server.name}.#{domain}\n"
    end

    begin
      Timeout::timeout(60) do
data=%x{
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -T -i #{pkey_path} root@#{gateway.external_ip_addr} bash <<-"EOF_BASH"

cat > /etc/hosts <<-EOF_CAT
#{hosts_file_data}
EOF_CAT
hostname "#{gateway.name}.#{domain}"
if [ -f /etc/sysconfig/network ]; then
  sed -e "s|^HOSTNAME.*|HOSTNAME=#{gateway.name}|" -i /etc/sysconfig/network
fi

for GUEST in #{guest_names}; do
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@$GUEST bash <<EOF_GUEST
cat > /etc/hosts <<-EOF_CAT
#{hosts_file_data}
EOF_CAT
hostname "$GUEST.#{domain}"
if [ -f /etc/sysconfig/network ]; then
  sed -e "s|^HOSTNAME.*|HOSTNAME=$GUEST|" -i /etc/sysconfig/network
fi
EOF_GUEST
done

EOF_BASH
}
        retval=$?
        if not retval.success? then
          raise "Failed to configure host files."
        end

      end
    rescue Exception => e
      raise "Timeout injecting configuring host files."
    end

    return true

  end

end
