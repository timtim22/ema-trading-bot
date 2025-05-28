class PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_position, only: [:show, :close_manually]
  
  def index
    @positions = Position.open.for_user(current_user).recent_first
    
    respond_to do |format|
      format.html
      format.json { render json: positions_json }
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.json { render json: position_json(@position) }
    end
  end
  
  def create
    @position = current_user.positions.build(position_params)
    @position.entry_time = Time.current
    @position.status = 'open'
    
    if @position.save
      respond_to do |format|
        format.html { redirect_to @position, notice: 'Position was successfully created.' }
        format.json { render json: position_json(@position), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @position.errors }, status: :unprocessable_entity }
      end
    end
  end
  
  def close_manually
    begin
      exit_price = params[:exit_price]&.to_f || @position.current_price
      
      if exit_price.nil?
        raise "No exit price available"
      end
      
      @position.close_manually!(exit_price)
      
      respond_to do |format|
        format.html { redirect_to positions_path, notice: 'Position closed successfully.' }
        format.json { 
          render json: { 
            success: true, 
            message: "Position closed at $#{exit_price}",
            position: position_json(@position)
          } 
        }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to positions_path, alert: "Error closing position: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def set_position
    @position = Position.for_user(current_user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to positions_path, alert: 'Position not found.' }
      format.json { render json: { error: 'Position not found' }, status: :not_found }
    end
  end
  
  def position_params
    params.require(:position).permit(:symbol, :amount, :entry_price, :take_profit, :stop_loss)
  end
  
  def positions_json
    @positions.map { |position| position_json(position) }
  end
  
  def position_json(position)
    {
      id: position.id,
      symbol: position.symbol,
      amount: position.amount,
      entry_price: position.entry_price,
      current_price: position.current_price,
      take_profit: position.take_profit,
      stop_loss: position.stop_loss,
      shares_quantity: position.shares_quantity,
      unrealized_pnl: position.unrealized_pnl,
      unrealized_pnl_percentage: position.unrealized_pnl_percentage,
      formatted_pnl: position.formatted_pnl,
      pnl_color_class: position.pnl_color_class,
      status: position.status,
      entry_time: position.entry_time,
      created_at: position.created_at
    }
  end
end
