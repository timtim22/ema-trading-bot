# frozen_string_literal: true

# Service to handle user-specific trading operations using their BotSetting parameters
class UserTradingService
  attr_reader :user, :symbol, :settings
  
  def initialize(user, symbol)
    @user = user
    @symbol = symbol
    @settings = BotSetting.for_user(user)
    @trading_bot_service = TradingBotService.new(symbol, @settings.timeframe, user)
  end
  
  # Execute a trade using user-specific settings
  def execute_trade_if_signal_confirmed(market_data)
    return false unless should_trade?
    
    # Check if we already have an open position for this symbol
    return false if Position.active.for_symbol(@symbol).for_user(@user).exists?
    
    # Use the TradingBotService with user-specific settings
    result = @trading_bot_service.run
    
    if result
      Rails.logger.info "UserTradingService: Trade executed for #{@user.email} on #{@symbol} using settings: profit=#{@settings.profit_percentage}%, loss=#{@settings.loss_percentage}%, confirmation_bars=#{@settings.confirmation_bars}"
    end
    
    result
  end
  
  # Check if user should trade this symbol
  def should_trade?
    # Check if user has this symbol configured
    return false unless @user.configured_symbols.include?(@symbol)
    
    # Check if user has valid settings
    return false unless @settings.valid?
    
    true
  end
  
  # Get user-specific trading parameters
  def trading_parameters
    {
      timeframe: @settings.timeframe,
      profit_percentage: @settings.profit_percentage,
      loss_percentage: @settings.loss_percentage,
      confirmation_bars: @settings.confirmation_bars,
      symbols: @user.configured_symbols
    }
  end
  
  # Check and close positions based on user settings
  def check_and_close_positions(current_price)
    positions = Position.active.for_symbol(@symbol).for_user(@user)
    return false unless positions.exists?
    
    closed_any = false
    profit_threshold = @settings.profit_percentage / 100.0
    loss_threshold = @settings.loss_percentage / 100.0
    
    positions.each do |position|
      # Calculate potential profit/loss percentage
      profit_loss_pct = (current_price - position.entry_price) / position.entry_price
      
      if profit_loss_pct >= profit_threshold
        # Take profit using user's setting
        position.close(current_price, "take_profit")
        Rails.logger.info "UserTradingService: Take profit executed for #{@user.email} on #{@symbol} at #{(@settings.profit_percentage)}% (#{(profit_loss_pct * 100).round(2)}%)"
        closed_any = true
      elsif profit_loss_pct <= -loss_threshold
        # Stop loss using user's setting
        position.close(current_price, "stop_loss")
        Rails.logger.info "UserTradingService: Stop loss executed for #{@user.email} on #{@symbol} at #{(@settings.loss_percentage)}% (#{(profit_loss_pct * 100).round(2)}%)"
        closed_any = true
      end
    end
    
    closed_any
  end
end 