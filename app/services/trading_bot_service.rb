# frozen_string_literal: true

# Service to coordinate the EMA trading bot operations
class TradingBotService
  attr_reader :last_error, :symbol, :timeframe
  
  def initialize(symbol = nil, timeframe = nil, user = nil)
    @symbol = symbol || ENV.fetch("DEFAULT_SYMBOL", "AAPL")
    @user = user
    
    # Get user-specific settings from database, fallback to ENV/defaults
    if @user
      user_settings = BotSetting.for_user(@user)
      @timeframe = timeframe || user_settings.timeframe || ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
      @profit_percentage = (user_settings.profit_percentage / 100.0) || ENV.fetch("PROFIT_PERCENTAGE", "1").to_f / 100.0
      @loss_percentage = (user_settings.loss_percentage / 100.0) || ENV.fetch("LOSS_PERCENTAGE", "1").to_f / 100.0
      @confirmation_bars = user_settings.confirmation_bars || ENV.fetch("CONFIRMATION_BARS", "3").to_i
    else
    @timeframe = timeframe || ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
      @profit_percentage = ENV.fetch("PROFIT_PERCENTAGE", "1").to_f / 100.0
      @loss_percentage = ENV.fetch("LOSS_PERCENTAGE", "1").to_f / 100.0
      @confirmation_bars = ENV.fetch("CONFIRMATION_BARS", "3").to_i
    end
    
    @trade_amount = ENV.fetch("TRADE_AMOUNT", "1000").to_f
    @alpaca_service = AlpacaDataService.new
    @order_service = OrderService.new
    
    Rails.logger.info "TradingBotService initialized for #{@symbol}: timeframe=#{@timeframe}, profit=#{(@profit_percentage * 100).round(2)}%, loss=#{(@loss_percentage * 100).round(2)}%, confirmation_bars=#{@confirmation_bars}"
  end
  
  # Run the full trading process: fetch data, calculate EMAs, check for signals, execute trades
  #
  # @return [Boolean] whether the process completed successfully
  def run
    # Fetch market data
    data = fetch_market_data
    return false unless data
    
    # Calculate EMAs
    closes = data[:closes]
    emas = calculate_emas(closes)
    return false unless emas
    
    # Save the EMA readings
    timestamp = data[:timestamp]
    save_ema_readings(emas, timestamp)
    
    # Check for trading signals and execute if found
    check_for_signals(emas)
    
    true
  rescue => e
    @last_error = "Trading bot error: #{e.message}"
    Rails.logger.error(@last_error)
    Rails.logger.error(e.backtrace.join("\n"))
    false
  end
  
  # Fetch current market data for the symbol and timeframe
  #
  # @return [Hash, nil] market data or nil if fetch failed
  def fetch_market_data
    data = @alpaca_service.fetch_closes_with_timestamp(@symbol, timeframe: @timeframe)
    
    unless data
      market_hours_error = check_market_hours
      if market_hours_error
        @last_error = market_hours_error
      else
        @last_error = "Failed to fetch market data: #{@alpaca_service.last_error || 'Unknown data feed issue'}"
      end
      Rails.logger.warn(@last_error)
      return nil
    end
    
    # Handle empty data case
    if data[:closes].nil? || data[:closes].empty?
      market_hours_error = check_market_hours
      if market_hours_error
        @last_error = market_hours_error
      else
        @last_error = "No price data returned for #{@symbol}. Possible data feed issue."
      end
      Rails.logger.warn(@last_error)
      return nil
    end
    
    data
  end
  
  # Check if current time is within market hours
  #
  # @return [String, nil] error message if outside market hours, nil otherwise
  def check_market_hours
    current_time = Time.current.in_time_zone('America/New_York')
    current_wday = current_time.wday
    
    # Weekend check (0 = Sunday, 6 = Saturday)
    if current_wday == 0 || current_wday == 6
      return "Outside market hours: weekend"
    end
    
    # Regular market hours are 9:30 AM to 4:00 PM ET
    market_open = current_time.change(hour: 9, min: 30)
    market_close = current_time.change(hour: 16, min: 0)
    
    if current_time < market_open
      return "Outside market hours: before market open (9:30 AM ET)"
    elsif current_time > market_close
      return "Outside market hours: after market close (4:00 PM ET)"
    end
    
    nil
  end
  
  # Calculate EMAs from the provided closing prices
  #
  # @param closes [Array<Float>] array of closing prices (oldest first)
  # @return [Hash, nil] hash containing calculated EMAs or nil if calculation failed
  def calculate_emas(closes)
    return nil if closes.nil? || closes.empty?
    
    # Use the EmaCalculatorService to calculate all EMAs in one call
    periods = [5, 8, 22]
    ema_data = EmaCalculatorService.calculate_ema_series(closes, periods)
    
    return nil if ema_data.empty?
    
    {
      # Individual EMA values for the most recent price
      ema5: ema_data[5],
      ema8: ema_data[8],
      ema22: ema_data[22],
      
      # Arrays of EMA values for trend analysis
      ema5_values: ema_data[:values][5],
      ema8_values: ema_data[:values][8],
      ema22_values: ema_data[:values][22]
    }
  end
  
  # Save the calculated EMA values to the database
  #
  # @param emas [Hash] hash containing calculated EMA values
  # @param timestamp [Time] timestamp for the readings
  # @return [Boolean] whether the save was successful
  def save_ema_readings(emas, timestamp)
    @alpaca_service.save_ema_readings(
      @symbol,
      ema5: emas[:ema5],
      ema8: emas[:ema8],
      ema22: emas[:ema22],
      timestamp: timestamp
    )
  end
  
  # Check for trading signals and execute trades accordingly
  #
  # @param emas [Hash] hash containing EMA values and arrays
  # @return [Boolean] whether a trade was executed
  def check_for_signals(emas)
    # First check if we're in an uptrend (EMA-5 > EMA-8 > EMA-22)
    return false unless EmaCalculatorService.uptrend?(
      emas[:ema5], emas[:ema8], emas[:ema22]
    )
    
    # Then check for a confirmed crossover
    if EmaCalculatorService.confirmed_crossover?(emas[:ema5_values], emas[:ema8_values])
      # Execute a buy trade
      execute_trade
      return true
    end
    
    # Check existing positions for exit conditions
    check_exits
    
    false
  end
  
  # Execute a buy trade
  #
  # @return [Position] the created position
  def execute_trade
    # Check if we already have an open position for this symbol
    return if Position.active.for_symbol(@symbol).user_scope(@user).exists?
    
    # Place the actual order via Alpaca API
    order_result = @order_service.place_buy_order_with_safety(
      @symbol,
      @trade_amount,
      profit_percent: @profit_percentage,
      loss_percent: @loss_percentage
    )
    
    return unless order_result
    
    # Create the position in our database
    position = Position.create!(
      user: @user,
      symbol: @symbol,
      amount: @trade_amount,
      entry_price: order_result[:fill_price] || 0.1,
      entry_time: Time.current,
      status: order_result[:status] == 'filled' ? 'open' : 'pending',
      primary_order_id: order_result[:primary_order_id],
      take_profit_order_id: order_result[:take_profit_order_id],
      stop_loss_order_id: order_result[:stop_loss_order_id],
      fill_qty: order_result[:fill_qty],
      fill_notional: order_result[:fill_price] ? (order_result[:fill_qty] * order_result[:fill_price]) : nil
    )
    
    # If order is not filled immediately, set up a job to check status later
    if position.status == 'pending'
      # This would be implemented as a background job in a real application
      # CheckOrderStatusJob.perform_later(position.id, order_result[:primary_order_id])
      Rails.logger.info("Order #{order_result[:primary_order_id]} is pending, will check status later")
    end
    
    position
  end
  
  # Check existing positions for exit conditions
  #
  # @return [Boolean] whether any positions were closed
  def check_exits
    # Get all active positions for the symbol
    positions = Position.active.for_symbol(@symbol)
    positions = positions.where(user: @user) if @user
    return false unless positions.exists?
    
    # Get the current price
    latest_data = @alpaca_service.fetch_bars(@symbol, limit: 1)
    return false unless latest_data
    
    latest_close = latest_data.dig("bars", 0, "c")
    return false unless latest_close
    
    # For each position, check take-profit and stop-loss conditions
    closed_any = false
    
    positions.each do |position|
      # Calculate potential profit/loss
      profit_loss_pct = (latest_close - position.entry_price) / position.entry_price
      
      if profit_loss_pct >= @profit_percentage
        # Take profit
        position.close(latest_close, "take_profit")
        closed_any = true
      elsif profit_loss_pct <= -@loss_percentage
        # Stop loss
        position.close(latest_close, "stop_loss")
        closed_any = true
      end
    end
    
    closed_any
  end
end 