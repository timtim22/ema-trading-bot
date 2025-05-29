class TradingHistoryController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @positions = build_positions_query
    @total_positions = @positions.count
    @total_profit_loss = @positions.sum(:profit_loss) || 0
    @profitable_trades = @positions.where(status: 'closed_profit').count
    @losing_trades = @positions.where(status: 'closed_loss').count
    @win_rate = @total_positions > 0 ? (@profitable_trades.to_f / @total_positions * 100).round(2) : 0
    
    # Apply pagination (50 per page as per requirements)
    @positions = @positions.page(params[:page]).per(20)
    
    respond_to do |format|
      format.html
      format.json { render json: positions_json }
    end
  end
  
  private
  
  def build_positions_query
    # Start with completed positions for current user, ordered by most recent
    positions = current_user.positions.completed.includes(:user).order(exit_time: :desc, created_at: :desc)
    
    # Apply date filters if provided
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        positions = positions.where('exit_time >= ?', start_date.beginning_of_day)
      rescue Date::Error
        # Invalid date format, ignore filter
      end
    end
    
    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
        positions = positions.where('exit_time <= ?', end_date.end_of_day)
      rescue Date::Error
        # Invalid date format, ignore filter
      end
    end
    
    # Apply symbol filter if provided
    if params[:symbol].present? && params[:symbol] != 'all'
      positions = positions.where(symbol: params[:symbol])
    end
    
    # Apply status filter if provided
    if params[:status].present? && params[:status] != 'all'
      positions = positions.where(status: params[:status])
    end
    
    positions
  end
  
  def positions_json
    @positions.map do |position|
      {
        id: position.id,
        symbol: position.symbol,
        amount: position.amount,
        entry_price: position.entry_price,
        exit_price: position.exit_price,
        entry_time: position.entry_time,
        exit_time: position.exit_time,
        exit_reason: position.exit_reason,
        profit_loss: position.profit_loss,
        profit_loss_percentage: position.profit_loss_percentage,
        status: position.status,
        shares_quantity: position.shares_quantity
      }
    end
  end
end 