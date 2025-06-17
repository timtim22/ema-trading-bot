class ExecuteTradeJob < ApplicationJob
  queue_as :default
  
  # Execute a trade for a given symbol and user
  # This job is enqueued when trading signals are detected
  def perform(symbol, user_id = nil, trade_amount = nil)
    Rails.logger.info "ExecuteTradeJob: Starting trade execution for #{symbol}"
    
    user = User.find(user_id) if user_id
    trade_amount ||= ENV.fetch("TRADE_AMOUNT", "1000").to_f
    
    # Create trading bot service instance
    trading_bot = TradingBotService.new(symbol, nil, user)
    
    # Check if we already have an open position for this symbol
    if Position.active.for_symbol(symbol).user_scope(user).exists?
      Rails.logger.info "ExecuteTradeJob: Position already exists for #{symbol}, skipping trade"
      return
    end
    
    # Execute the trade using the service's execute_trade method
    position = trading_bot.execute_trade
    
    if position
      Rails.logger.info "ExecuteTradeJob: Successfully executed trade for #{symbol} - Position ID: #{position.id}"
      
      # Log the trade execution
      ActivityLog.log_trade(
        symbol,
        'buy',
        position.entry_price,
        user: user,
        details: {
          position_id: position.id,
          amount: trade_amount,
          order_id: position.primary_order_id
        }
      ) if defined?(ActivityLog)
      
    else
      Rails.logger.error "ExecuteTradeJob: Failed to execute trade for #{symbol}: #{trading_bot.last_error}"
    end
    
  rescue => e
    Rails.logger.error "ExecuteTradeJob: Error executing trade for #{symbol}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end 