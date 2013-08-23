require 'timeout'

SERVER_NAME_PREFIX=ENV['SERVER_NAME_PREFIX']
if SERVER_NAME_PREFIX.blank? then
  puts "SERVER_NAME_PREFIX is required in order to use this script."
  exit 1
end
Account.find(:all, :conditions => ["username IS NOT NULL AND username != '' AND api_key IS NOT NULL AND api_key != ''"], :group => "api_key, region").each do |acct|
  begin
  conn = acct.get_connection
  conn.all_servers do |server|

    exp = Regexp.new("^#{SERVER_NAME_PREFIX}")
    if server.name and server.name =~ exp then

      pool_server = PoolServer.find(:first, :conditions => ["cloud_server_id = ? AND historical = 0", server.id])
      server_ref = Server.find(:first, :conditions => ["cloud_server_id_number = ? AND historical = 0", server.id])

      if server_ref.nil? and pool_server.nil? then
        begin
          puts "Account: #{acct.username}, Deleting server ID: #{server.id} #{server.name}"
          Timeout::timeout(30) do
            conn.update_server(server.id, {:name => "deleted_#{server.id}"})
            conn.destroy_server(server.id)
          end
        rescue
          puts "Error deleting server ID: #{server.id} #{server.name}"
        end

      end

      # Check for case where group is historical but servers
      # didn't get marked as historical
      if server_ref and server_ref.server_group.historical then
        server_ref.make_historical
      end

    end

  end

  rescue Exception => e
    puts "Failed to cleanup servers for account: #{acct.id}, #{acct.username}. #{e.message}"
  end

end
