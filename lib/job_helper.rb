class JobHelper

  def self.handle_retry(&code)
    5.times do
      begin
        ActiveRecord::Base.connection_handler.verify_active_connections!
        code.call
        break
      rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid
        sleep 1
      end
    end
  end

end
