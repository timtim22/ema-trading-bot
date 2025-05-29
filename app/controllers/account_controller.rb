class AccountController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @account_service = AccountService.new
    
    # Fetch account information from Alpaca
    @account_info = @account_service.get_account_info
    
    if @account_info
      # Calculate performance metrics
      @performance_metrics = @account_service.calculate_performance_metrics(@account_info)
      
      # Get current positions from Alpaca
      @alpaca_positions = @account_service.get_positions
      
      # Get recent activities
      @recent_activities = @account_service.get_activities(limit: 10)
      
      # Calculate additional metrics
      calculate_additional_metrics
      
      Rails.logger.info "AccountController: Successfully loaded account data (#{@account_info[:source]})"
    else
      Rails.logger.error "AccountController: Failed to load account data: #{@account_service.last_error}"
      flash.now[:alert] = "Unable to load account data. Please try again later."
    end
    
    respond_to do |format|
      format.html
      format.json { render json: account_json }
    end
  end
  
  # Refresh account data via AJAX
  def refresh
    @account_service = AccountService.new
    @account_info = @account_service.get_account_info
    
    if @account_info
      @performance_metrics = @account_service.calculate_performance_metrics(@account_info)
      @alpaca_positions = @account_service.get_positions
      calculate_additional_metrics
      
      render json: {
        success: true,
        account_info: @account_info,
        performance_metrics: @performance_metrics,
        positions_count: @alpaca_positions.length,
        last_updated: Time.current.strftime("%I:%M:%S %p")
      }
    else
      render json: {
        success: false,
        error: @account_service.last_error
      }
    end
  end
  
  private
  
  def calculate_additional_metrics
    return unless @account_info && @alpaca_positions
    
    # Calculate position metrics
    @total_positions = @alpaca_positions.length
    @profitable_positions = @alpaca_positions.count { |p| p[:unrealized_pl] > 0 }
    @losing_positions = @alpaca_positions.count { |p| p[:unrealized_pl] < 0 }
    
    # Calculate total unrealized P/L
    @total_unrealized_pl = @alpaca_positions.sum { |p| p[:unrealized_pl] }
    @total_unrealized_pl_percent = @alpaca_positions.any? ? 
      (@alpaca_positions.sum { |p| p[:unrealized_plpc] } / @alpaca_positions.length) : 0
    
    # Calculate largest position
    @largest_position = @alpaca_positions.max_by { |p| p[:market_value].abs } if @alpaca_positions.any?
    
    # Calculate day trading info
    @day_trades_remaining = [4 - @account_info[:daytrade_count], 0].max
    @is_pattern_day_trader = @account_info[:pattern_day_trader]
  end
  
  def account_json
    {
      account_info: @account_info,
      performance_metrics: @performance_metrics,
      positions: @alpaca_positions,
      activities: @recent_activities,
      metrics: {
        total_positions: @total_positions,
        profitable_positions: @profitable_positions,
        losing_positions: @losing_positions,
        total_unrealized_pl: @total_unrealized_pl,
        total_unrealized_pl_percent: @total_unrealized_pl_percent,
        day_trades_remaining: @day_trades_remaining,
        is_pattern_day_trader: @is_pattern_day_trader
      }
    }
  end
end 