class SshPublicKey < ActiveRecord::Base

  attr_accessible :description, :public_key, :user_id, :server_group_id

  validates_presence_of :description, :public_key
  belongs_to :server_group
  belongs_to :user

end
