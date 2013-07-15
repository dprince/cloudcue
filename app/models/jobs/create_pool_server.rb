require 'job_helper'

class CreatePoolServer

  @queue=:linux

  def self.perform(id)
    JobHelper.handle_retry do
      pool_server = PoolServer.find(id)
      pool_server.create_pool_server
    end
  end

end
