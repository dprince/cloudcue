class SshKeypair < ActiveRecord::Base

  attr_accessible :public_key, :private_key, :server_group_id

  validates_presence_of :public_key, :private_key
  belongs_to :server_group

end
