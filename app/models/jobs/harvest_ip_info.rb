require 'job_helper'

class HarvestIpInfo

  @queue=:linux

  def self.perform(id)
    JobHelper.handle_retry do
      server = Server.find(id)
      server.harvest_ip_info
    end
  end

end
