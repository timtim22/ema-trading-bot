class PositionService
  def self.create_position(user, params)
    symbol = params[:symbol]
    amount = params[:amount].to_f
    
    # Get current market price for entry using Alpaca
    market_data = MarketDataService.get_current_price(symbol)
    current_price = market_data[:price]
    
    # Calculate position details
    shares = amount / current_price
    
    # Create position with real market data
    position = user.positions.build(
      symbol: symbol,
      amount: amount,
      entry_price: current_price,
      current_price: current_price,
      take_profit: params[:take_profit],
      stop_loss: params[:stop_loss],
      status: 'open',
      entry_time: Time.current
    )
    
    if position.save
      Rails.logger.info "PositionService: Created position #{position.id} for #{user.email} - #{symbol} @ $#{current_price} (#{market_data[:source]})"
      position
    else
      Rails.logger.error "PositionService: Failed to create position: #{position.errors.full_messages}"
      nil
    end
  end
  
  def self.create_market_order(user, symbol, amount, order_type = 'buy')
    # Use Alpaca Trading API for real orders
    case Rails.env
    when 'production'
      create_real_alpaca_order(user, symbol, amount, order_type)
    when 'development'
      # Use Alpaca sandbox in development
      create_real_alpaca_order(user, symbol, amount, order_type)
    else
      create_simulated_order(user, symbol, amount, order_type)
    end
  end
  
  # Create a real trading position with Alpaca API
  def self.create_trading_position(user, symbol, amount, take_profit_percent: 1.0, stop_loss_percent: 1.0)
    begin
      order_service = OrderService.new
      
      # Place buy order with safety orders (take-profit and stop-loss)
      order_result = order_service.place_buy_order_with_safety(
        symbol, 
        amount, 
        profit_percent: take_profit_percent,
        loss_percent: stop_loss_percent
      )
      
      if order_result
        # Create position record in database
        position = user.positions.create!(
          symbol: symbol,
          amount: amount,
          entry_price: order_result[:fill_price] || 0,
          current_price: order_result[:fill_price] || 0,
          status: order_result[:status] == 'filled' ? 'open' : 'pending',
          entry_time: Time.current,
          # Store Alpaca order IDs for tracking
          primary_order_id: order_result[:primary_order_id],
          stop_loss_order_id: order_result[:stop_loss_order_id],
          take_profit_order_id: order_result[:take_profit_order_id]
        )
        
        Rails.logger.info "PositionService: Created trading position #{position.id} with Alpaca order #{order_result[:primary_order_id]}"
        position
      else
        Rails.logger.error "PositionService: Failed to place Alpaca order: #{order_service.last_error}"
        nil
      end
    rescue => e
      Rails.logger.error "PositionService: Error creating trading position: #{e.message}"
      nil
    end
  end
  
  # Close a position using Alpaca API
  def self.close_position(position)
    begin
      order_service = OrderService.new
      
      # Cancel any existing stop-loss and take-profit orders
      if position.stop_loss_order_id.present?
        order_service.cancel_orders_for_symbol(position.symbol)
      end
      
      # Get current position size from Alpaca
      # This would require querying Alpaca for the actual position
      # For now, we'll calculate based on our records
      shares = position.amount / position.entry_price
      
      # Place market sell order
      sell_order = ALPACA_CLIENT.new_order(
        symbol: position.symbol,
        qty: shares.to_i,
        side: 'sell',
        type: 'market',
        time_in_force: 'day'
      )
      
      if sell_order
        # Update position record
        position.update!(
          status: 'closed',
          exit_time: Time.current,
          exit_price: position.current_price, # Will be updated when order fills
          close_order_id: sell_order.id
        )
        
        Rails.logger.info "PositionService: Closed position #{position.id} with Alpaca sell order #{sell_order.id}"
        position
      else
        Rails.logger.error "PositionService: Failed to place sell order for position #{position.id}"
        nil
      end
    rescue => e
      Rails.logger.error "PositionService: Error closing position #{position.id}: #{e.message}"
      nil
    end
  end
  
  private
  
  def self.create_real_alpaca_order(user, symbol, amount, order_type)
    # Use the existing OrderService for Alpaca integration
    order_service = OrderService.new
    
    case order_type
    when 'buy'
      # Place a buy order and create position record
      order_result = order_service.place_buy_order_with_safety(symbol, amount)
      
      if order_result
        create_position(user, {
          symbol: symbol,
          amount: amount,
          alpaca_order_id: order_result[:primary_order_id]
        })
      end
    when 'sell'
      # Handle sell orders (would need existing position)
      Rails.logger.warn "PositionService: Sell orders should use close_position method"
      nil
    end
  end
  
  def self.create_simulated_order(user, symbol, amount, order_type)
    # For testing - create position immediately with simulated data
    create_position(user, {
      symbol: symbol,
      amount: amount
    })
  end
end 