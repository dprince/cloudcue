class ServerCommand < ActiveRecord::Base

  belongs_to :server

  attr_accessible :command, :server_id

end
