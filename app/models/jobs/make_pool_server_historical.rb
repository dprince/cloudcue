require 'job_helper'

class MakePoolServerHistorical

  @queue=:linux

  def self.perform(id)
    JobHelper.handle_retry do
      pool_server = PoolServer.find(id)
      pool_server.make_historical
    end
  end

end
