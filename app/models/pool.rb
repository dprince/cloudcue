class Pool < ActiveRecord::Base
  has_many :pool_servers, :conditions => "historical = 0"
  belongs_to :user
  belongs_to :image, :primary_key => "image_ref", :foreign_key => "image_ref"
  validates_numericality_of :size
  validates_presence_of :flavor_ref, :image_ref, :user_id, :size

  attr_accessible :image_ref, :flavor_ref, :size, :user_id 

  after_create :handle_after_create
  def handle_after_create
    self.size.times do
      make_pool_server
    end
  end

  def sync

    # if there are too many servers delete some
    server_count = 0
    if self.pool_servers.size > self.size then
      (self.pool_servers.size - self.size).times do |i|
        AsyncExec.run_job(MakePoolServerHistorical, self.pool_servers[i-1].id)
      end
    end

    # make the servers match the pool
    server_count = 0
    self.pool_servers.each do |pool_server|
      server_count += 1
      if pool_server.flavor_ref != self.flavor_ref or
         pool_server.image_ref != self.image_ref then
        AsyncExec.run_job(MakePoolServerHistorical, pool_server.id)
        make_pool_server
      end
      if pool_server.created_at < 1.day.ago and pool_server.status == 'Pending' then
        AsyncExec.run_job(MakePoolServerHistorical, pool_server.id)
      end
    end

    # add extras
    (self.size - server_count).times do
      make_pool_server
    end

  end

  def make_pool_server
   pool_server = PoolServer.create(
      :pool_id => self.id,
      :flavor_ref => self.flavor_ref,
      :image_ref => self.image_ref,
      :account_id => self.user.account.id
    )
    AsyncExec.run_job(CreatePoolServer, pool_server.id)
  end

  def make_historical
    update_attribute(:historical, true)
    self.pool_servers.each do |pool_server|
      AsyncExec.run_job(MakePoolServerHistorical, pool_server.id)
    end
  end

end
