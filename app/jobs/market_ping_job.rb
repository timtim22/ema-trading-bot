class MarketPingJob < ApplicationJob
  queue_as :default

  # Class method to check if job is running for a symbol
  def self.running_for_symbol?(symbol)
    # For simplicity, we'll check if the bot state is running
    # In a more complex system, you might track job IDs
    BotState.running?(symbol)
  end

  # Enhanced job to send comprehensive market data for chart updates
  def perform(symbol = "AAPL")
    Rails.logger.info "MarketPingJob: Starting job for #{symbol} at #{Time.current}"
    
    # Check if bot is still running for this symbol
    bot_state = BotState.for_symbol(symbol)
    Rails.logger.info "MarketPingJob: Bot state for #{symbol} - Running: #{bot_state.running?}, Last run: #{bot_state.last_run_at}"
    
    unless bot_state.running?
      Rails.logger.info "MarketPingJob: Bot stopped for #{symbol}, exiting job"
      return
    end
    
    # Update last run timestamp
    bot_state.update!(last_run_at: Time.current)
    Rails.logger.info "MarketPingJob: Updated last_run_at for #{symbol}"
    
    # Generate comprehensive market data using Alpaca
    market_data = generate_market_data_with_alpaca(symbol)
    
    # Detect trading signals for all users
    detect_and_broadcast_signals(symbol, market_data)
    
    # Update position current prices for this symbol
    update_position_prices(symbol, market_data[:price])
    
    # Broadcast ping message to users who have this symbol configured
    broadcast_to_users_with_symbol(symbol, {
      type: "ping",
      symbol: symbol,
      timestamp: Time.current.to_i,
      message: "Market ping from Alpaca API!",
      price: market_data[:price],
      source: market_data[:source]
    })
    
    # Also broadcast comprehensive market update for charts to users with this symbol
    broadcast_to_users_with_symbol(symbol, {
      type: "market_update",
      symbol: symbol,
      timestamp: Time.current.to_i,
      price: market_data[:price],
      ohlc: market_data[:ohlc],
      emas: market_data[:emas],
      volume: market_data[:volume],
      source: market_data[:source]
    })
    
    # Re-schedule this job to run again in 10 seconds if bot is still running
    # Check again to avoid race conditions
    bot_state.reload
    if bot_state.running?
      Rails.logger.info "MarketPingJob: Scheduling next job for #{symbol} in 10 seconds"
      MarketPingJob.set(wait: 10.seconds).perform_later(symbol)
    else
      Rails.logger.info "MarketPingJob: Bot stopped for #{symbol}, not rescheduling"
    end
  end
  
  private
  
  # Generate comprehensive market data using Alpaca API
  def generate_market_data_with_alpaca(symbol)
    begin
      # Get current price from Alpaca
      price_data = MarketDataService.get_current_price(symbol)
      current_price = price_data[:price]
      source = price_data[:source]
      
      # Get OHLC data from Alpaca
      ohlc_data = MarketDataService.get_ohlc_data(symbol)
      ohlc = {
        open: ohlc_data[:open],
        high: ohlc_data[:high],
        low: ohlc_data[:low],
        close: ohlc_data[:close]
      }
      
      # Get historical data for EMA calculations
      historical_data = MarketDataService.get_historical_closes(symbol, limit: 50)
      emas = calculate_emas_from_closes(historical_data[:closes])
      
      # Use volume from OHLC data
      volume = ohlc_data[:volume]
      
      Rails.logger.info "MarketPingJob: Generated market data for #{symbol} - Price: $#{current_price} (#{source})"
      
      {
        price: current_price,
        ohlc: ohlc,
        emas: emas,
        volume: volume,
        source: source
      }
    rescue => e
      Rails.logger.error "MarketPingJob: Error generating Alpaca market data for #{symbol}: #{e.message}"
      # Fallback to simulated data
      generate_simulated_market_data(symbol)
    end
  end
  
  # Fallback to simulated data if Alpaca fails
  def generate_simulated_market_data(symbol)
    Rails.logger.warn "MarketPingJob: Using simulated data for #{symbol}"
    
    # Get or initialize price history for this symbol
    @price_history ||= {}
    @price_history[symbol] ||= initialize_price_history(symbol)
    
    history = @price_history[symbol]
    previous_close = history[:prices].last || get_base_price(symbol)
    
    # Generate new price
    new_price = generate_realistic_price(previous_close)
    
    # Generate OHLC data (simulating a 1-minute candle)
    ohlc = generate_ohlc(previous_close, new_price)
    
    # Update price history
    history[:prices] << new_price
    history[:prices] = history[:prices].last(100) # Keep last 100 prices
    
    # Calculate EMAs
    emas = calculate_emas_from_closes(history[:prices])
    
    # Generate volume
    volume = generate_volume
    
    {
      price: new_price,
      ohlc: ohlc,
      emas: emas,
      volume: volume,
      source: 'simulated'
    }
  end
  
  # Calculate EMAs from closing prices (proper exponential moving averages)
  def calculate_emas_from_closes(closes)
    return { ema5: 0, ema8: 0, ema22: 0 } if closes.empty?
    
    # Calculate proper EMAs using exponential smoothing
    ema5 = calculate_ema(closes, 5)
    ema8 = calculate_ema(closes, 8)
    ema22 = calculate_ema(closes, 22)
    
    {
      ema5: ema5.round(2),
      ema8: ema8.round(2),
      ema22: ema22.round(2)
    }
  end
  
  # Calculate exponential moving average
  def calculate_ema(prices, period)
    return 0 if prices.empty?
    return prices.last if prices.length == 1
    
    # EMA multiplier
    multiplier = 2.0 / (period + 1)
    
    # Start with simple moving average for the first value
    if prices.length < period
      return prices.sum / prices.length
    end
    
    # Calculate EMA
    ema = prices.first(period).sum / period # Initial SMA
    
    prices.drop(period).each do |price|
      ema = (price * multiplier) + (ema * (1 - multiplier))
    end
    
    ema
  end
  
  # Initialize price history for a symbol
  def initialize_price_history(symbol)
    base_price = get_base_price(symbol)
    prices = []
    
    # Generate initial price history (last 50 prices)
    50.times do |i|
      change = (rand - 0.5) * 0.02 # ±1% change
      price = base_price * (1 + change)
      prices << price.round(2)
      base_price = price
    end
    
    { prices: prices }
  end
  
  # Get base price for a symbol
  def get_base_price(symbol)
    base_prices = {
      "AAPL" => 185.5,
      "MSFT" => 402.5,
      "GOOG" => 171.2,
      "AMZN" => 178.3,
      "TSLA" => 248.5,
      "NVDA" => 875.2
    }
    
    base_prices[symbol] || 100.0
  end
  
  # Generate realistic price movement
  def generate_realistic_price(previous_price)
    # Random walk with slight upward bias
    change_pct = (rand - 0.48) * 2 # Slight upward bias
    new_price = previous_price * (1 + change_pct / 100.0)
    
    # Ensure price doesn't go below $1
    [new_price, 1.0].max.round(2)
  end
  
  # Generate OHLC data for a candle
  def generate_ohlc(previous_close, current_price)
    open = previous_close
    close = current_price
    
    # Generate high and low with some volatility
    volatility = 0.005 # 0.5% volatility
    range = open * volatility
    
    high = [open, close].max + (rand * range)
    low = [open, close].min - (rand * range)
    
    # Ensure high >= max(open, close) and low <= min(open, close)
    high = [high, open, close].max
    low = [low, open, close].min
    
    {
      open: open.round(2),
      high: high.round(2),
      low: low.round(2),
      close: close.round(2)
    }
  end
  
  # Generate random volume
  def generate_volume
    # Generate volume between 100K and 2M
    base_volume = 500_000
    variation = (rand - 0.5) * 0.8 # ±40% variation
    volume = (base_volume * (1 + variation)).to_i
    
    [volume, 10_000].max # Minimum 10K volume
  end
  
  # Update current prices for all open positions of this symbol
  def update_position_prices(symbol, current_price)
    begin
      positions = Position.open.for_symbol(symbol)
      
      if positions.any?
        Rails.logger.info "MarketPingJob: Updating #{positions.count} positions for #{symbol} with price $#{current_price}"
        
        positions.update_all(current_price: current_price)
        
        Rails.logger.debug "MarketPingJob: Updated position prices for #{symbol}"
      end
    rescue => e
      Rails.logger.error "MarketPingJob: Error updating position prices for #{symbol}: #{e.message}"
    end
  end
  
  # Detect and broadcast trading signals for all users
  def detect_and_broadcast_signals(symbol, market_data)
    begin
      # Get previous EMA values for comparison
      previous_emas = get_previous_emas(symbol)
      current_emas = market_data[:emas]
      current_price = market_data[:price]
      
      # Skip if we don't have previous data for comparison
      return unless previous_emas
      
      # Check for signals for each user
      User.find_each do |user|
        signal = TradingSignal.detect_crossover_signal(
          symbol, 
          current_emas, 
          previous_emas, 
          current_price, 
          user
        )
        
        if signal
          Rails.logger.info "🚨 MarketPingJob: #{signal.signal_type.upcase} signal detected for #{symbol} at $#{current_price} for user #{user.id}"
          
          # Broadcast signal to user-specific channel
          ActionCable.server.broadcast("trading_signals_user_#{user.id}", {
            type: "trading_signal",
            signal: {
              id: signal.id,
              symbol: signal.symbol,
              signal_type: signal.signal_type,
              price: signal.price.to_f,
              ema5: signal.ema5.to_f,
              ema8: signal.ema8.to_f,
              ema22: signal.ema22.to_f,
              timestamp: signal.timestamp.to_i,
              formatted_time: signal.formatted_time,
              formatted_price: signal.formatted_price,
              signal_description: signal.signal_description,
              badge_class: signal.signal_badge_class
            }
          })
          
          # Also broadcast to general market channel for dashboard updates
          ActionCable.server.broadcast("market_channel", {
            type: "trading_signal",
            symbol: symbol,
            signal_type: signal.signal_type,
            price: current_price,
            timestamp: Time.current.to_i,
            user_id: user.id
          })
        end
      end
      
      # Store current EMAs for next comparison
      store_current_emas(symbol, current_emas)
      
    rescue => e
      Rails.logger.error "MarketPingJob: Error detecting signals for #{symbol}: #{e.message}"
    end
  end
  
  # Get previous EMA values for comparison
  def get_previous_emas(symbol)
    @previous_emas ||= {}
    @previous_emas[symbol]
  end
  
  # Store current EMA values for next comparison
  def store_current_emas(symbol, emas)
    @previous_emas ||= {}
    @previous_emas[symbol] = emas
  end

  # Broadcast to users who have this symbol configured
  def broadcast_to_users_with_symbol(symbol, message)
    User.find_each do |user|
      if user.configured_symbols.include?(symbol)
        Rails.logger.info "MarketPingJob: Broadcasting #{message[:type]} for #{symbol} to user #{user.email}"
        ActionCable.server.broadcast("market_channel_#{user.id}", message)
      end
    end
  end
end 