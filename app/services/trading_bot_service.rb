# frozen_string_literal: true

# Service to coordinate the EMA trading bot operations
class TradingBotService
  attr_reader :last_error, :symbol, :timeframe
  
  def initialize(symbol = nil, timeframe = nil)
    @symbol = symbol || ENV.fetch("DEFAULT_SYMBOL", "AAPL")
    @timeframe = timeframe || ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
    @trade_amount = ENV.fetch("TRADE_AMOUNT", "1000").to_f
    @profit_percentage = ENV.fetch("PROFIT_PERCENTAGE", "1").to_f / 100
    @loss_percentage = ENV.fetch("LOSS_PERCENTAGE", "1").to_f / 100
    @alpaca_service = AlpacaDataService.new
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
    data = @alpaca_service.fetch_ema_data(@symbol, timeframe: @timeframe)
    
    unless data
      @last_error = "Failed to fetch market data: #{@alpaca_service.last_error}"
      return nil
    end
    
    data
  end
  
  # Calculate EMAs from the provided closing prices
  #
  # @param closes [Array<Float>] array of closing prices (oldest first)
  # @return [Hash, nil] hash containing calculated EMAs or nil if calculation failed
  def calculate_emas(closes)
    return nil if closes.nil? || closes.empty?
    
    # Generate arrays of EMA values (will have fewer elements than closes)
    ema5_values = []
    ema8_values = []
    ema22_values = []
    
    # Calculate for each window to get the full series of EMA values
    # Start with enough candles to calculate the longer EMA (22)
    (22..closes.length).each do |i|
      window = closes[0...i]
      ema5_values << EmaCalculatorService.calculate_ema(window, 5)
      ema8_values << EmaCalculatorService.calculate_ema(window, 8)
      ema22_values << EmaCalculatorService.calculate_ema(window, 22)
    end
    
    {
      ema5_values: ema5_values,
      ema8_values: ema8_values,
      ema22_values: ema22_values,
      # Most recent values
      ema5: ema5_values.last,
      ema8: ema8_values.last,
      ema22: ema22_values.last
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
    return if Position.active.for_symbol(@symbol).exists?
    
    # Get the current price (latest close)
    latest_data = @alpaca_service.fetch_bars(@symbol, limit: 1)
    return unless latest_data
    
    latest_close = latest_data.dig("bars", 0, "c")
    return unless latest_close
    
    # Create the position
    position = Position.create!(
      user: User.first, # You might want a more sophisticated way to determine the user
      symbol: @symbol,
      amount: @trade_amount,
      entry_price: latest_close,
      entry_time: Time.current,
      status: 'open'
    )
    
    # In a real implementation, this is where you'd place the actual order with Alpaca
    # and update the position with the actual execution details
    
    position
  end
  
  # Check existing positions for exit conditions
  #
  # @return [Boolean] whether any positions were closed
  def check_exits
    # Get all active positions for the symbol
    positions = Position.active.for_symbol(@symbol)
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