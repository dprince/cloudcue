require 'rackspace_connection'
require 'openstack_connection'

class Account < ActiveRecord::Base

  belongs_to :user

  attr_accessible :username, :api_key, :region, :connection_type, :auth_url

  def get_connection
    if self.connection_type == 'rackspace' then
      return RackspaceConnection.new(self.username, self.api_key, self.auth_url, self.region)
    elsif self.connection_type == 'openstack' then
      return OpenstackConnection.new(self.username, self.api_key, self.auth_url, self.region)
    else
      raise "Unsupported account connection type."
    end
  end

end
