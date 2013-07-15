require 'job_helper'

class ConfigureServer

  @queue=:linux

  def self.perform(id)
    JobHelper.handle_retry do
      server = Server.find(id)
      server.loop_until_server_online
      server.inject_keys

      #if all servers are online then configure hosts files
      count=Server.count(:conditions => ["server_group_id = ? AND status != 'Online' AND id != ?", server.server_group_id, server.id])
      server.server_group.configure_ssh_and_hosts if count == 0

      server.status = "Online"
      server.save!

    end
  end

end
