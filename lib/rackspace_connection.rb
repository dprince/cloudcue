require 'rubygems'
require 'fog'

# wrapper around all Rackspace Cloud Servers API calls
class RackspaceConnection

  @cs_conn=nil

  def initialize(username, api_key, auth_url, region)
    if auth_url.blank? then
      auth_url = 'https://identity.api.rackspacecloud.com/v2.0/tokens'    
    end

    @cs_conn = Fog::Compute.new(
      :provider           => :openstack,
      :openstack_auth_url  => auth_url,
      :openstack_username => username,
      :openstack_api_key => api_key,
      :openstack_region => region,
      :openstack_service_name => 'cloudServersOpenStack',
      :openstack_endpoint_type => 'publicURL'
    )

  end

  #return an array containing the server id and admin password
  def create_server(name, image_id, flavor_id, personalities=[])
    server = @cs_conn.servers.create(
      :name => name,
      :image_ref => image_id,
      :flavor_ref => flavor_id,
      :personality => personalities)
    [server.id, server.password]
  end

  # returns a hash containing detailed server info
  def get_server(id)
    cs = @cs_conn.servers.get(id)
    server = {
     :id => cs.id,
     :progress => cs.progress,
     :status => cs.state,
     :public_ip => nil,
     :private_ip => nil
    }
    begin
      server[:public_ip] = find_ip(cs, "public") 
      server[:private_ip] = find_ip(cs, "private") 
    rescue Exception
    end
    server
  end

  def update_server(id, data)
    server = @cs_conn.update_server(id, data)
  end

  def destroy_server(id)
    server = @cs_conn.servers.get(id)
    server.destroy
  end

  def reboot_server(id)
    server = get_server(id)
    server.reboot
  end

  # returns an array of :id, :name hashes
  def all_servers

    if block_given? then
      @cs_conn.servers.each do |server|
        yield server
      end
    else
      @cs_conn.servers
    end

  end

  # returns an array of :id, :name hashes
  def all_images

    if block_given? then
      @cs_conn.images.each do |image|
        yield image
      end
    else
      @cs_conn.images
    end

  end

  def account_limits
    @cs_conn.get_limits.body['limits']
  end

  private
  def find_ip(server, label, version=4)
    # lookup the first public IP address and use that for verification
    if server.addresses.nil? or server.addresses[label].nil?
      raise("No address found for network label #{label}. Addresses: #{server.addresses}")
    end
    addresses = server.addresses[label].select {|a| a['version'] == version}
    if addresses.nil? or addresses.empty? then
      raise("No address found for network label #{label}. Addresses: #{server.addresses}")
    end
    address = addresses[0]['addr']
    if address.nil? or address.empty? then
      raise("No address found for network label #{label}. Addresses: #{server.addresses}")
    end
    address
  end

end
