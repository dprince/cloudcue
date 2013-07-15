require 'async_exec'

class ServerGroupsController < ApplicationController

  before_filter :authorize
  before_filter :require_admin_or_self, :only => [:show, :destroy]

  # GET /server_groups
  # GET /server_groups.json
  # GET /server_groups.xml
  def index

  if request.format == Mime::XML
    limit=params[:limit].nil? ? 1000: params[:limit]
  else
    limit=params[:limit].nil? ? 50 : params[:limit]
  end

  if is_admin then
    @server_groups = ServerGroup.paginate :conditions => ["historical = ?", false], :page => params[:page] || 1, :per_page => limit, :order => "name", :include => [ { :user => [:account] } ]
  else
    @server_groups = ServerGroup.paginate :conditions => ["user_id = ? AND historical = ?", session[:user_id], false], :page => params[:page] || 1, :per_page => limit, :order => "name", :include => [ { :user => [:account] } ]
  end

    if params[:layout] then
      respond_to do |format|
        format.html # index.html.erb
      end
    else
      respond_to do |format|
        format.html { render :partial => "table" }
        format.json  { render :json => @server_groups }
        format.xml  { render :xml => @server_groups }
      end
    end

  end

  # GET /server_groups/new
  # GET /server_groups/new.xml
  def new
    @server_group = ServerGroup.new
    @account = User.find(session[:user_id]).account

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @server_group }
    end
  end

  # GET /server_groups/1
  # GET /server_groups/1.json
  # GET /server_groups/1.xml
  def show
    @server_group = ServerGroup.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json  { render :json => @server_group.to_json(:include => :servers ) }
      format.xml  { render :xml => @server_group.to_xml(:include => :servers) }
    end
  end

  # POST /server_groups
  # POST /server_groups.json
  # POST /server_groups.xml
  def create

    respond_to do |format|
      format.html {
        sg_params=params[:server_group]
          @server_group = ServerGroup.create({
          :description => sg_params[:description],
          :name => sg_params[:name],
          :domain_name => sg_params[:domain_name],
          :owner_name => sg_params[:owner_name],
          :user_id => session[:user_id]
        })
          @server_group.user_id = session[:user_id]
        if params[:server_group]["servers_attributes"] then
          params[:server_group]["servers_attributes"].each_pair do |id, hash|
            user=User.find(session[:user_id])
            hash[:account_id] = user.account.id
            server = Server.new_for_type(hash)
            @server_group.servers << server
          end
        end

      }
      format.xml {
        hash=Hash.from_xml(request.raw_post)
          @server_group=server_group_from_hash(hash)
      }
      format.json {
        hash=JSON.parse(request.raw_post)
        hash={"server_group" => hash}
        @server_group=server_group_from_hash(hash)
      }
  end

    respond_to do |format|
      if @server_group.save
        flash[:notice] = 'ServerGroup was successfully created.'
        @server_group.servers.each do |server|
          AsyncExec.run_job(CreateCloudServer, server.id)
        end
        #format.html { redirect_to(@server_group) }
        format.html  { render :xml => @server_group.to_xml(:include => :servers), :status => :created, :location => @server_group, :content_type => "application/xml" }
        format.json  { render :json => @server_group.to_json(:include => :servers), :status => :created, :location => @server_group }
        format.xml  { render :xml => @server_group.to_xml(:include => :servers), :status => :created, :location => @server_group }
      else
        #@server_group.errors.each do |error|
        #  puts error.to_s
        #end
        if not @server_group.new_record? then
          @server_group.servers.each do |server|
            server.delete
          end
          @server_group.delete
        end
        format.html  { render :xml => @server_group.errors.to_xml, :status => :unprocessable_entity, :content_type => "application/xml" }
        format.json  { render :json => @server_group.errors, :status => :unprocessable_entity }
        format.xml  { render :xml => @server_group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /server_groups/1
  # DELETE /server_groups/1.json
  # DELETE /server_groups/1.xml
  def destroy
    @server_group = ServerGroup.find(params[:id])
    xml=@server_group.to_xml
    json=@server_group.to_json
    @server_group.update_attribute('historical', true)
  AsyncExec.run_job(MakeGroupHistorical, @server_group.id)

    respond_to do |format|
      format.html { redirect_to(server_groups_url) }
      format.json  { render :json => json }
      format.xml  { render :xml => xml }
    end

  end

private
  def require_admin_or_self
    return true if is_admin
    server_group = ServerGroup.find(params[:id])
    return true if session[:user_id] and server_group and session[:user_id] == server_group.user_id
    render :text => "Attempt to view an unauthorized record.", :status => "401"
    return false
  end

  def server_group_from_hash(hash)

    servers=[]
    ssh_public_keys=[]

    if hash["server_group"]["servers"] then
      hash["server_group"]["servers"].each do |server_hash|
        user=User.find(session[:user_id])
        server_hash[:account_id] = user.account.id
        server = Server.new_for_type(server_hash)
        servers << server
      end
    end

    if hash["server_group"]["ssh_public_keys"] then
      hash["server_group"]["ssh_public_keys"].each do |ssh_key_hash|
        ssh_public_keys << SshPublicKey.new(ssh_key_hash)
      end
    end

    group_hash=hash["server_group"]
    group_hash.delete("servers")
    group_hash.delete("ssh_public_keys")
    group_hash[:user_id] = session[:user_id]
    server_group = ServerGroup.create(group_hash)
    server_group.servers << servers
    server_group.ssh_public_keys << ssh_public_keys
    return server_group
  end

end
