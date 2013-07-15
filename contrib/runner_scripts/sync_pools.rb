Pool.find(:all, :conditions => "historical = 0").each do |pool|
  begin
    pool.sync
  rescue Exception => e
    puts "Failed to sync pool: #{pool.id}"
  end
end
