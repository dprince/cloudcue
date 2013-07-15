class ServerError < ActiveRecord::Base

  attr_accessible :error_message, :cloud_server_id_number

  validates_presence_of :error_message
  belongs_to :server

end
