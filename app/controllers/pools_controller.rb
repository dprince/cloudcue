class PoolsController < ApplicationController

  before_filter :authorize
  before_filter :require_admin_or_self, :only => [:show, :update, :delete]

  # GET /pools
  # GET /pools.json
  # GET /pools.xml
  def index

    if request.format == Mime::XML
      limit=params[:limit].nil? ? 1000: params[:limit]
    else
      limit=params[:limit].nil? ? 50 : params[:limit]
    end

    @pools = Pool.paginate :page => params[:page] || 1, :per_page => limit, :conditions => ["user_id = ? AND historical = ?", session[:user_id], 0], :order => "id"

    respond_to do |format|
      format.xml  { render :xml => @pools }
      format.any  { render :json => @pools }
    end
  end

  # GET /pools/1
  # GET /pools/1.json
  # GET /pools/1.xml
  def show
    @pool = Pool.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json  { render :json => @pool, :include => :image }
      format.xml  { render :xml => @pool, :include => :image }
    end
  end

  # POST /pools
  # POST /pools.json
  # POST /pools.xml
  def create
    @pool = Pool.new(params[:pool])
    @pool.user_id = session[:user_id]

    respond_to do |format|
      if @pool.save
        format.xml  { render :xml => @pool, :status => :created, :location => @pool, :include => :image }
        format.any  { render :json => @pool, :status => :created, :location => @pool, :include => :image }
      else
        format.xml  { render :xml => @pool.errors, :status => :unprocessable_entity }
        format.any  { render :json => @pool.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /pools/1
  # PUT /pools/1.json
  # PUT /pools/1.xml
  def update
    @pool = Pool.find(params[:id])

    respond_to do |format|
      if @pool.update_attributes(params[:pool]) and @pool.sync
        format.html { redirect_to(@pool, :notice => 'Pool was successfully updated.') }
        format.json  { render :json => @pool, :include => :image }
        format.xml  { render :xml => @pool, :include => :image }
      else
        format.xml  { render :xml => @pool.errors, :status => :unprocessable_entity }
        format.any  { render :json => @pool.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /pools/1
  # DELETE /pools/1.json
  # DELETE /pools/1.xml
  def destroy
    @pool = Pool.find(params[:id])
    xml=@pool.to_xml
    json=@pool.to_json
    @pool.make_historical

    respond_to do |format|
      format.html { redirect_to(pools_url) }
      format.json  { render :json => json}
      format.xml  { render :xml => xml}
    end
  end

  private
  def require_admin_or_self
    return true if is_admin
    pool = Pool.find(params[:id])
    return true if session[:user_id] and pool and pool.user_id and session[:user_id] == pool.user_id
    render :text => "Attempt to view an unauthorized record.", :status => "401"
    return false
  end

end
