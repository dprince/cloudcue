require 'logger'
require 'async_exec'
require 'util/ssh'
require 'timeout'
require 'tempfile'

class LinuxServer < Server

  # method to block until a server is online
  def loop_until_server_online(pkey_path = self.server_group.ssh_key_basepath)
    conn = self.account_connection

    error_message = "Failed to build server."

    timeout = self.server_online_timeout-(Time.now-self.updated_at).to_i
    timeout = 120 if timeout < 120

    begin
      Timeout::timeout(timeout) do

        # poll the server until progress is 100%
        server = conn.get_server(self.cloud_server_id_number)
        until server[:progress] == 100 and server[:status] == "ACTIVE" do
          server = conn.get_server(self.cloud_server_id_number)
          raise "Server in error state." if server[:status] == 'ERROR'
          sleep 1
        end

        error_message="Failed to ssh to the node."  
        if ! system(%{

            COUNT=0
            while ! ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -T -i #{pkey_path} root@#{server[:public_ip]} /bin/true > /dev/null 2>&1; do
              if (($COUNT > 23)); then
                exit 1
              fi
              ((COUNT++))
              sleep 15
            done
            exit 0

        }) then
          fail_and_raise error_message
        end

      end
    rescue Exception => e
      fail_and_raise error_message
    end

  end
  
  def capture_pool_server

    private_key = nil

    PoolServer.transaction do
      pool_server = PoolServer.where('account_id = ? AND image_ref = ? AND flavor_ref = ? AND status = ? AND historical = ?', self.account_id, self.image_id, self.flavor_id, 'Online', 0).lock(true).first 
      if pool_server then

        self.cloud_server_id_number = pool_server.cloud_server_id
        self.external_ip_addr = pool_server.external_ip_addr
        self.internal_ip_addr = pool_server.internal_ip_addr
        self.save

        pool_server.historical = true;
        pool_server.save!

        private_key = Tempfile.new "pool_priv_key"
        private_key.chmod(0600)
        private_key.write(pool_server.private_key)
        private_key.flush

      else
        return false
      end
    end
       
    inject_keys(private_key.path)
    private_key.close(true)
    return true

  end

  def inject_keys(pkey_path=self.server_group.ssh_key_basepath)

    begin
      Timeout::timeout(60) do
data=%x{
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -T -i #{pkey_path} root@#{self.external_ip_addr} bash <<-"EOF_BASH"
echo '#{generate_authorized_keys}' > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo '#{IO.read(self.server_group.ssh_key_basepath)}' > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
EOF_BASH
}
        retval=$?
        if not retval.success? then
          fail_and_raise "Failed to inject personalities into captured server."
        end

      end
    rescue Exception => e
      fail_and_raise "Timeout injecting personalities into captured server."
    end

    return true

  end

  # Get authorized_keys that should be injected into the group
  private
  def generate_authorized_keys

    # server group keys
    auth_key_set=Set.new(self.server_group.ssh_public_keys.collect { |x| x.public_key.chomp })
    # user keys
    auth_key_set.merge(self.server_group.user.ssh_public_keys.collect { |x| x.public_key.chomp })

    # new lines
    authorized_keys=auth_key_set.inject("") { |sum, key| sum + key + "\n"}

    # add any keys from the config files
    if not ENV['AUTHORIZED_KEYS'].blank? then
      authorized_keys += ENV['AUTHORIZED_KEYS']
    end

    # write keys to a file
    authorized_keys += IO.read(self.server_group.ssh_key_basepath+".pub")

    return authorized_keys

  end

  # Generates a personalities hash suitable for use with bindings (Fog)
  private
  def generate_personalities
    personalities=[{'contents' => IO.read(self.server_group.ssh_key_basepath+".pub"), 'path' => '/root/.ssh/authorized_keys'}]
    return personalities
  end

end
