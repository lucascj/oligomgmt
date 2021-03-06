class PoolsController < ApplicationController
  #require_role "stanford"
  load_and_authorize_resource
  
  def new_params
    @pool_types   = Pool.pool_types.insert(0,'')
  end
  
  def list_for_pool
    if !params[:pool_type].blank? && !params[:pool_string].blank?  
      condition_array = define_pool_conditions(params)
      @current_pools = Pool.find_all_pools(condition_array)
    end
    
    if !params[:plate_string].blank?
      condition_array = define_plate_conditions(params[:plate_string])
      @current_plates = PlateTube.find_all_plates(condition_array)
    end
      
    if !params[:cpick_string].blank?
      condition_array = define_plate_conditions(params[:cpick_string])
      @plate_positions = PlatePosition.find_all_positions(condition_array)
    end
    
    if !@current_pools.nil? || !@current_plates.nil? || !@plate_positions.nil?
      @pool = Pool.new
      @checked = false
      @storage_locations = StorageLocation.order('room_nr, shelf_nr').all
      render :action => 'list_for_pool'
    else
      flash.now[:notice] = 'Please enter valid pool type and numbers, and/or plate numbers for new pool'
      @pool_types = Pool.pool_types.insert(0,'')
      render :action => 'new_params'
    end
  end
  
  def new_query
    @pool_types = Pool.pool_types 
  end
  
  # GET /pools
  # GET /pools.xml
  def index
    if params[:id]
      @pools = Pool.where('pools.id = ?', params[:id]).all
    elsif params[:pool_type] || params[:pool_string]
      condition_array = define_pool_conditions(params)
      @pools = Pool.find_all_pools(condition_array)
    else
      @pools = Pool.find_all_pools
    end
    render :action => 'index'
  end

  # GET /pools/1
  # GET /pools/1.xml
  def show
    @pool = Pool.find(params[:id])
    @from_pools = Pool.where('id in (?)', @pool.from_pools).all.collect(&:tube_label) if @pool.from_pools
    @from_plates = PlateTube.where('id IN (?)', @pool.from_plates).all.collect(&:plate_or_tube_name) if @pool.from_plates
    render :action => 'show'
  end
  
  def get_oligos
    @pool = Pool.includes(:plate_positions).find(params[:id])
    render :partial => 'show_oligos', :locals => {:pool => @pool}
  end

  # GET /pools/1/edit
  def edit
    @pool = Pool.find(params[:id])
    @from_pools = Pool.where('id in (?)', @pool.from_pools).all.collect(&:tube_label) if @pool.from_pools
    @from_plates = PlateTube.where('id IN (?)', @pool.from_plates).all.collect(&:plate_or_tube_name) if @pool.from_plates
    @storage_locations = StorageLocation.order('room_nr, shelf_nr').all
  end
  
  # POST /pools
  # POST /pools.xml
  def create
    #
    # TODO - Work on error handling.  Ideally should return to same state as submitted form, with correct boxes checked
    #
    @pool = Pool.new(params[:pool])
    @total_oligos = 0
    #render :action => 'debug'
    
    if params[:pool_id]         # Selecting from pools list
      @current_pools = Pool.includes(:aliquot_to_pools).where('id IN (?)', params[:pool_id].keys).all
      @checked_pool_ids = params[:pool_id].reject {|id, val| val == '0'}.keys
      @pool.from_pools = @checked_pool_ids
      @pool.total_oligos += Pool.where('id IN (?)', @checked_pool_ids).sum(:total_oligos)

      aliquot_to_pools = AliquotToPool.where('pool_id IN (?)', @checked_pool_ids).all
      aliquot_to_pools.each {|aliquot| @pool.aliquot_to_pools.build(:plate_position_id => aliquot.plate_position_id)}
    end
    
    if params[:plate_tube_id]    # Selecting entire plate/tube(s)
      @current_plates = PlateTube.where('id IN (?)', params[:plate_tube_id].keys).all
      @checked_plate_ids = params[:plate_tube_id].reject {|id, val| val == '0'}.keys
      @pool.from_plates = @checked_plate_ids
      @pool.total_oligos += SynthOligo.includes(:plate_position).where('plate_positions.plate_or_tube_id IN (?)', @checked_plate_ids).count(:id)
        
      plate_positions = PlatePosition.where('plate_or_tube_id IN (?)', @checked_plate_ids).all
      plate_positions.each {|plate_position| @pool.aliquot_to_pools.build(:plate_position_id => plate_position.id)}
    end
    
    if params[:plate_position_id]  # Cherrypicking oligos from plate(s)
      @plate_positions = PlatePosition.where('id IN (?)', params[:plate_position_id].keys).all
      @checked_pposition_ids = params[:plate_position_id].reject {|id, val| val == '0'}.keys
      
      @pool.cherrypick_oligos = SynthOligo.where('plate_position_id IN (?)', @checked_pposition_ids).count(:id)
      @pool.total_oligos     += @pool.cherrypick_oligos
      
      # build aliquot_to_pools, only for checked plates 
      @checked_pposition_ids.each {|p_id| @pool.aliquot_to_pools.build(:plate_position_id => p_id)}          
    end
    
    if @pool.save
      flash[:notice] = "Pool successfully created comprising #{@pool.total_oligos} oligos"
      redirect_to(@pool)
    else
      flash[:notice] = "Validation error creating pool"
      @storage_locations = StorageLocation.order('room_nr, shelf_nr').all
      #render :action => 'debug'
      render :action => 'list_for_pool'
    end
  end

  # PUT /pools/1
  # PUT /pools/1.xml
  def update
    @pool = Pool.find(params[:id])
    if !param_blank?(params[:pool_string])
      pool_array = create_array_from_text_area(params[:pool_string])
      @from_pools = Pool.where('tube_label IN (?)', pool_array).all
      @pool.from_pools = @from_pools.collect(&:id) if !@from_pools.nil?
    end
    
    if !param_blank?(params[:plate_string])
      @condition_array = define_plate_conditions(params[:plate_string])
      @from_plates = PlateTube.where(*@condition_array).all if !@condition_array.empty?
      @pool.from_plates = (@from_plates.nil? ? [] : @from_plates.collect(&:id))
    end
    
    #render :action => 'debug'
  
    if @pool.update_attributes(params[:pool])
      flash[:notice] = 'Pool was successfully updated.'
      redirect_to(@pool)
    else
      render :action => "edit"
    end
  end

  # DELETE /pools/1
  # DELETE /pools/1.xml
  def destroy
    @pool = Pool.includes(:aliquot_to_pools).find(params[:id])
    @pool.destroy

    redirect_to(pools_url)
  end
  
protected
  def define_pool_conditions(params)
    @where_select = []; @where_values = []; 
    @where_select, @where_values = pool_where_clause(params[:pool_type], params[:pool_string])       
    sql_where_array = (@where_select.length == 0 ? [] : [@where_select.join(' AND ')].concat(@where_values))
    return sql_where_array
  end
  
  def define_plate_conditions(plate_string)
    @where_select = [];  @where_values = []; 
    @where_select, @where_values = plate_where_clause(plate_string) if !plate_string.blank?       
    sql_where_array = (@where_select.length == 0 ? [] : [@where_select.join(' AND ')].concat(@where_values))
    return sql_where_array
  end
 
end
