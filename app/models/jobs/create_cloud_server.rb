require 'job_helper'

class CreateCloudServer

  @queue=:linux

  def self.perform(id)
    JobHelper.handle_retry do
      server = Server.find(id)
      server.create_cloud_server
    end
  end

end
