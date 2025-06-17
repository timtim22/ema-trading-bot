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
      @timeframe = timeframe || user_settings.timeframe || ENV.fetch("DEFAULT_TIMEFRAME", "5m")
      @profit_percentage = (user_settings.profit_percentage / 100.0) || ENV.fetch("PROFIT_PERCENTAGE", "1").to_f / 100.0
      @loss_percentage = (user_settings.loss_percentage / 100.0) || ENV.fetch("LOSS_PERCENTAGE", "1").to_f / 100.0
      @confirmation_bars = user_settings.confirmation_bars || ENV.fetch("CONFIRMATION_BARS", "3").to_i
    else
    @timeframe = timeframe || ENV.fetch("DEFAULT_TIMEFRAME", "5m")
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
  # @param async [Boolean] whether to execute trades asynchronously (default: true)
  # @return [Boolean] whether the process completed successfully
  def run(async: true)
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
    check_for_signals(emas, async: async)
    
    true
  rescue => e
    @last_error = "Trading bot error: #{e.message}"
    Rails.logger.error(@last_error)
    Rails.logger.error(e.backtrace.join("\n"))
    false
  end
  
  # Fetch current market data for the symbol and timeframe with retry logic
  #
  # @param max_retries [Integer] maximum number of retry attempts (default: 3)
  # @return [Hash, nil] market data or nil if fetch failed after all retries
  def fetch_market_data(max_retries: 3)
    attempt = 0
    
    while attempt <= max_retries
      begin
        data = @alpaca_service.fetch_closes_with_timestamp(@symbol, timeframe: @timeframe)
        
        # Check if we got data
        if data && data[:closes] && !data[:closes].empty?
          # Success case - log if we had to retry
          if attempt > 0
            Rails.logger.info("Successfully fetched market data for #{@symbol} after #{attempt} retry attempts")
          end
          return data
        end
        
        # Handle nil data or empty closes
        market_hours_error = check_market_hours
        if market_hours_error
          @last_error = market_hours_error
          Rails.logger.warn(@last_error)
          return nil  # Don't retry market hours issues
        end
        
        # Determine error message
        if data.nil?
          error_msg = "Failed to fetch market data: #{@alpaca_service.last_error || 'Unknown data feed issue'}"
        else
          error_msg = "No price data returned for #{@symbol}. Possible data feed issue."
        end
        
        # Check if we should retry
        if attempt < max_retries
          attempt += 1
          delay = calculate_retry_delay(attempt)
          Rails.logger.warn("#{error_msg} - Retry attempt #{attempt}/#{max_retries} in #{delay} seconds")
          sleep(delay)
          next  # Continue to next iteration
        else
          @last_error = "#{error_msg} - All #{max_retries} retry attempts exhausted"
          Rails.logger.error(@last_error)
          return nil
        end
        
      rescue => e
        # Handle exceptions with retry logic
        error_msg = "Exception while fetching market data for #{@symbol}: #{e.message}"
        
        if retryable_error?(e) && attempt < max_retries
          attempt += 1
          # Check if this is a rate limit error for longer delays
          is_rate_limit = rate_limit_error?(e)
          delay = calculate_retry_delay(attempt, is_rate_limit: is_rate_limit)
          
          if is_rate_limit
            Rails.logger.warn("#{error_msg} - Rate limit detected, using extended backoff. Retry attempt #{attempt}/#{max_retries} in #{delay} seconds")
          else
            Rails.logger.warn("#{error_msg} - Retry attempt #{attempt}/#{max_retries} in #{delay} seconds")
          end
          
          sleep(delay)
          next  # Continue to next iteration
        else
          @last_error = attempt >= max_retries ? 
            "#{error_msg} - All #{max_retries} retry attempts exhausted" : 
            "#{error_msg} - Non-retryable error"
          Rails.logger.error(@last_error)
          Rails.logger.error(e.backtrace.join("\n"))
          return nil
        end
      end
    end
    
    # This should never be reached due to the logic above
    @last_error = "Unexpected error in retry logic"
    Rails.logger.error(@last_error)
    nil
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
    
    # Check for US stock market holidays
    holiday_name = market_holiday?(current_time)
    if holiday_name
      return "Outside market hours: holiday (#{holiday_name})"
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
  # @param async [Boolean] whether to execute trades asynchronously (default: true)
  # @return [Boolean] whether a trade signal was detected
  def check_for_signals(emas, async: true)
    # First check if we're in an uptrend (EMA-5 > EMA-8 > EMA-22)
    return false unless EmaCalculatorService.uptrend?(
      emas[:ema5], emas[:ema8], emas[:ema22]
    )
    
    # Then check for a confirmed crossover
    if EmaCalculatorService.confirmed_crossover?(emas[:ema5_values], emas[:ema8_values])
      if async
        # Enqueue a trade execution job (new behavior)
        ExecuteTradeJob.perform_later(@symbol, @user&.id, @trade_amount)
        Rails.logger.info "TradingBotService: Enqueued ExecuteTradeJob for #{@symbol}"
      else
        # Execute trade immediately (original behavior)
        execute_trade
        Rails.logger.info "TradingBotService: Executed trade synchronously for #{@symbol}"
      end
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
    # Use a database transaction to ensure atomicity and prevent race conditions
    Position.transaction do
      # Check for existing active positions within the transaction
      # This reduces the race condition window but doesn't eliminate it entirely
      existing_position = Position.where(
        user: @user,
        symbol: @symbol,
        status: ['open', 'pending']
      ).lock(true).first  # Use SELECT FOR UPDATE to prevent concurrent reads
      
      if existing_position
        Rails.logger.info("TradingBotService: Active position #{existing_position.id} already exists for #{@user&.email} - #{@symbol}")
        return nil
      end
      
      # Place the actual order via Alpaca API
      order_result = @order_service.place_buy_order_with_safety(
        @symbol,
        @trade_amount,
        profit_percent: @profit_percentage * 100.0,
        loss_percent: @loss_percentage * 100.0
      )

      return nil unless order_result

      begin
        # Create the position in our database with database-level race condition protection
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
          # Schedule a background job to monitor the order status
          CheckOrderStatusJob.perform_later(position.id, order_result[:primary_order_id])
          Rails.logger.info("Order #{order_result[:primary_order_id]} is pending, scheduled CheckOrderStatusJob for monitoring")
        end

        position

      rescue ActiveRecord::RecordNotUnique => e
        # This handles the race condition - another thread created a position first
        # This should be very rare due to the transaction and locking above
        Rails.logger.warn("TradingBotService: Concurrent position creation detected for #{@user&.email} - #{@symbol} despite transaction locking")
        
        # Find the existing position that was created by the other thread
        existing_position = Position.where(
          user: @user, 
          symbol: @symbol, 
          status: ['open', 'pending']
        ).first
        
        if existing_position
          Rails.logger.info("TradingBotService: Using existing position #{existing_position.id} instead of creating duplicate")
          return nil  # Return nil to indicate we didn't create a new position
        else
          # This should not happen, but if it does, re-raise the error
          Rails.logger.error("TradingBotService: Unique constraint violation but no existing active position found")
          raise e
        end
        
      rescue ActiveRecord::RecordInvalid => e
        # Handle validation errors
        Rails.logger.error("TradingBotService: Failed to create position: #{e.message}")
        return nil
      end
    end
  rescue => e
    Rails.logger.error("TradingBotService: Transaction failed during execute_trade: #{e.message}")
    nil
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
  
  private
  
  # Calculate exponential back-off delay with jitter
  #
  # @param attempt [Integer] the retry attempt number (1-based)
  # @param is_rate_limit [Boolean] whether this is a rate limit error (optional)
  # @return [Float] delay in seconds
  def calculate_retry_delay(attempt, is_rate_limit: false)
    base_delay = is_rate_limit ? 5.0 : 2.0  # Longer base delay for rate limits
    max_delay = is_rate_limit ? 60.0 : 16.0  # Higher cap for rate limits
    
    # Exponential back-off: base_delay * (2 ** (attempt - 1)) seconds
    delay = [base_delay * (2 ** (attempt - 1)), max_delay].min
    
    # Add jitter (random factor between 0.5 and 1.5) to avoid thundering herd
    jitter = 0.5 + rand * 1.0
    (delay * jitter).round(2)
  end
  
  # Determine if an error should trigger a retry
  #
  # @param error [Exception] the error that occurred
  # @return [Boolean] whether the error is retryable
  def retryable_error?(error)
    # Retryable errors: network issues, timeouts, rate limits, temporary server errors
    retryable_patterns = [
      /timeout/i,
      /connection/i,
      /network/i,
      /rate limit/i,
      /429/,  # HTTP 429 Too Many Requests
      /temporarily unavailable/i,
      /service unavailable/i,
      /internal server error/i,
      /bad gateway/i,
      /gateway timeout/i
    ]
    
    # Check if it's a known retryable exception type
    retryable_classes = [
      Faraday::TimeoutError,
      Faraday::ConnectionFailed,
      JSON::ParserError  # Sometimes API returns invalid JSON during issues
    ]
    
    return true if retryable_classes.any? { |klass| error.is_a?(klass) }
    
    # Check error message for retryable patterns
    error_message = error.message.to_s
    retryable_patterns.any? { |pattern| error_message.match?(pattern) }
  end
  
  # Check if an error is specifically a rate limit error
  #
  # @param error [Exception] the error that occurred
  # @return [Boolean] whether the error is a rate limit error
  def rate_limit_error?(error)
    error_message = error.message.to_s
    rate_limit_patterns = [
      /rate limit/i,
      /429/,
      /too many requests/i,
      /quota.*exceeded/i
    ]
    
    rate_limit_patterns.any? { |pattern| error_message.match?(pattern) }
  end
  
  # Check if the given date is a US stock market holiday
  #
  # @param date [Time] the date to check
  # @return [String, nil] holiday name if it's a holiday, nil otherwise
  def market_holiday?(date)
    year = date.year
    month = date.month
    day = date.day
    
    # Fixed date holidays
    return "New Year's Day" if month == 1 && day == 1
    return "Independence Day" if month == 7 && day == 4
    return "Christmas Day" if month == 12 && day == 25
    
    # Martin Luther King Jr. Day (3rd Monday in January)
    mlk_day = third_monday_of_month(year, 1)
    return "Martin Luther King Jr. Day" if date.to_date == mlk_day
    
    # Presidents' Day (3rd Monday in February)
    presidents_day = third_monday_of_month(year, 2)
    return "Presidents' Day" if date.to_date == presidents_day
    
    # Good Friday (Friday before Easter - complex calculation)
    good_friday = easter_date(year) - 2.days
    return "Good Friday" if date.to_date == good_friday
    
    # Memorial Day (last Monday in May)
    memorial_day = last_monday_of_month(year, 5)
    return "Memorial Day" if date.to_date == memorial_day
    
    # Juneteenth (June 19)
    return "Juneteenth" if month == 6 && day == 19
    
    # Labor Day (1st Monday in September)
    labor_day = first_monday_of_month(year, 9)
    return "Labor Day" if date.to_date == labor_day
    
    # Thanksgiving (4th Thursday in November)
    thanksgiving = fourth_thursday_of_month(year, 11)
    return "Thanksgiving Day" if date.to_date == thanksgiving
    
    nil
  end
  
  # Helper methods for holiday calculations
  def third_monday_of_month(year, month)
    first_day = Date.new(year, month, 1)
    # Find first Monday
    first_monday = first_day + (1 - first_day.wday) % 7
    # Add 2 weeks to get third Monday
    first_monday + 14.days
  end
  
  def last_monday_of_month(year, month)
    last_day = Date.new(year, month, -1)
    # Find last Monday
    last_day - (last_day.wday + 6) % 7
  end
  
  def first_monday_of_month(year, month)
    first_day = Date.new(year, month, 1)
    # Find first Monday
    first_day + (1 - first_day.wday) % 7
  end
  
  def fourth_thursday_of_month(year, month)
    first_day = Date.new(year, month, 1)
    # Find first Thursday
    first_thursday = first_day + (4 - first_day.wday) % 7
    # Add 3 weeks to get fourth Thursday
    first_thursday + 21.days
  end
  
  # Easter date calculation (Western Easter)
  def easter_date(year)
    # Algorithm for calculating Easter date
    a = year % 19
    b = year / 100
    c = year % 100
    d = b / 4
    e = b % 4
    f = (b + 8) / 25
    g = (b - f + 1) / 3
    h = (19 * a + b - d - g + 15) % 30
    i = c / 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) / 451
    month = (h + l - 7 * m + 114) / 31
    day = ((h + l - 7 * m + 114) % 31) + 1
    
    Date.new(year, month, day)
  end
end 