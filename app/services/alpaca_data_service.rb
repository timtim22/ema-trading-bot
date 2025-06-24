# frozen_string_literal: true

# Service to interact with Alpaca Markets API for retrieving market data
class AlpacaDataService
  BASE_URL = "https://data.alpaca.markets/v2"
  
  attr_reader :last_response, :last_error
  
  def initialize(api_key_id = nil, api_secret_key = nil)
    @api_key_id = api_key_id || ENV.fetch("ALPACA_API_KEY_ID")
    @api_secret_key = api_secret_key || ENV.fetch("ALPACA_API_SECRET_KEY")
  end
  
  # Fetch bar data for a given symbol and timeframe
  #
  # @param symbol [String] the stock symbol (e.g., "AAPL")
  # @param timeframe [String] the time interval (e.g., "5Min", "1D")
  # @param limit [Integer] maximum number of bars to return
  # @param from [String, nil] start date/time in ISO 8601 format
  # @param to [String, nil] end date/time in ISO 8601 format
  # @return [Hash, nil] parsed response data or nil if the request failed
  def fetch_bars(symbol,
                 timeframe: ENV.fetch("POLL_TIMEFRAME") || "5Min",
                 limit: ENV.fetch("POLL_LIMIT") || 50,
                 from: nil,
                 to: nil)
    # Smart data fetching strategy that works within subscription limits
    if from.nil? && to.nil?
      # Strategy: Try to get the most recent data available within subscription limits
      # Most basic Alpaca plans allow data that's 15+ minutes old
      
      current_time = Time.current
      est_time = current_time.in_time_zone('America/New_York')
      
      # Try recent data first (15 minutes ago to account for SIP data limitations)
      recent_end_time = current_time - 15.minutes
      recent_start_time = recent_end_time - 2.hours
      
      Rails.logger.info "Attempting to fetch recent data for #{symbol} (15+ minutes delayed)"
      
      # First attempt: Try recent data within subscription limits
      to = recent_end_time.utc.iso8601
      from = recent_start_time.utc.iso8601
    end
    
    params = { timeframe: timeframe, limit: limit }
    params[:start] = from if from
    params[:end] = to if to

    response = connection.get("stocks/#{symbol}/bars", params)
    @last_response = response
    
    # Log rate limit information
    if response.headers['x-ratelimit-remaining']
      Rails.logger.info("Alpaca API Rate Limit: #{response.headers['x-ratelimit-remaining']}/#{response.headers['x-ratelimit-limit']} requests remaining")
      
      # Alert if getting low on remaining requests
      if response.headers['x-ratelimit-remaining'].to_i < 10
        Rails.logger.warn("Alpaca API Rate Limit Warning: Only #{response.headers['x-ratelimit-remaining']} requests remaining!")
      end
    end
    
    if response.success?
      result = JSON.parse(response.body)
      
      # Log the data freshness for debugging
      if result["bars"] && result["bars"].any?
        latest_timestamp = Time.parse(result["bars"].last["t"]) rescue nil
        if latest_timestamp
          age_hours = ((Time.current - latest_timestamp) / 3600).round(1)
          age_minutes = ((Time.current - latest_timestamp) / 60).round(1)
          Rails.logger.info "Latest data timestamp: #{latest_timestamp} (#{age_hours} hours / #{age_minutes} minutes old)"
        end
      end
      
      result
    elsif response.status == 403 && response.body.include?("recent SIP data")
      # Handle subscription limitation gracefully
      @last_error = "Subscription limits prevent real-time data access. Using available market data within subscription limits."
      Rails.logger.warn("#{@last_error} Falling back to longer delay...")
      
      # Fallback: Try data from yesterday during market hours
      fallback_strategy(symbol, timeframe, limit)
    else
      @last_error = "Alpaca Data Error (#{response.status}): #{response.body}"
      Rails.logger.error(@last_error)
      nil
    end
  end
  
  # Extract just the closing prices from bar data
  #
  # @param symbol [String] the stock symbol (e.g., "AAPL")
  # @param timeframe [String] the time interval (e.g., "5Min", "1D")
  # @param limit [Integer] maximum number of bars to return
  # @return [Array<Float>, nil] array of closing prices or nil if the request failed
  def fetch_closes(symbol, timeframe: "5Min", limit: 50)
    data = fetch_bars(symbol, timeframe: timeframe, limit: limit)
    return nil unless data
    
    bars = data["bars"]
    if bars.nil?
      @last_error = "No bars returned for #{symbol}. Possible market closure or data issue."
      return nil
    end
    
    bars.map { |bar| bar["c"] }
  end
  
  # Fetch closing prices with timestamp
  #
  # @param symbol [String] the stock symbol (e.g., "AAPL") 
  # @param timeframe [String] the time interval (e.g., "5Min", "1D")
  # @param limit [Integer] maximum number of bars to return
  # @return [Hash, nil] hash with close prices and timestamp
  def fetch_closes_with_timestamp(symbol, timeframe: ENV["POLL_TIMEFRAME"], limit: ENV["POLL_LIMIT"])
    data = fetch_bars(symbol, timeframe: timeframe, limit: limit)
    return nil unless data
    
    bars = data["bars"]
    return nil if bars.nil? || bars.empty?
    
    # Extract closes
    closes = bars.map { |bar| bar["c"] }
    
    # Use the timestamp from the last (most recent) bar
    last_bar_time = Time.parse(bars.last["t"]) rescue Time.current
    
    {
      symbol: symbol,
      timeframe: timeframe,
      closes: closes,
      timestamp: last_bar_time
    }
  end
  
  # Save EMA readings to the database
  #
  # @param symbol [String] the stock symbol (e.g., "AAPL")
  # @param ema5 [Float] the 5-period EMA value
  # @param ema8 [Float] the 8-period EMA value
  # @param ema22 [Float] the 22-period EMA value
  # @param timestamp [Time] the timestamp for this reading
  # @return [Boolean] whether the save was successful
  def save_ema_readings(symbol, ema5:, ema8:, ema22:, timestamp: Time.current)
    ActiveRecord::Base.transaction do
      EmaReading.create!(
        symbol: symbol,
        period: 5,
        value: ema5,
        timestamp: timestamp
      )
      
      EmaReading.create!(
        symbol: symbol,
        period: 8,
        value: ema8,
        timestamp: timestamp
      )
      
      EmaReading.create!(
        symbol: symbol,
        period: 22,
        value: ema22,
        timestamp: timestamp
      )
    end
    
    true
  rescue => e
    Rails.logger.error("Failed to save EMA readings: #{e.message}")
    false
  end
  
  def rate_limit_info
    return {} unless @last_response
    
    {
      remaining: @last_response.headers['x-ratelimit-remaining'],
      limit: @last_response.headers['x-ratelimit-limit'],
      reset: @last_response.headers['x-ratelimit-reset'],
    }
  end
  
  private
  
  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.headers["APCA-API-KEY-ID"] = @api_key_id
      f.headers["APCA-API-SECRET-KEY"] = @api_secret_key
      f.adapter Faraday.default_adapter
    end
  end

  def fallback_strategy(symbol, timeframe, limit)
    # Use the most recent trading day data that should be accessible
    current_time = Time.current
    est_time = current_time.in_time_zone('America/New_York')
    
    # Get yesterday's market hours (or Friday if it's weekend)
    trading_day = est_time.wday == 1 ? est_time - 3.days : est_time - 1.day # Monday goes to Friday
    
    market_start = trading_day.change(hour: 9, min: 30)
    market_end = trading_day.change(hour: 16, min: 0)
    
    params = {
      timeframe: timeframe,
      limit: limit,
      start: market_start.utc.iso8601,
      end: market_end.utc.iso8601
    }

    Rails.logger.info "Fallback: Fetching #{symbol} data from #{market_start.strftime('%Y-%m-%d %H:%M %Z')} to #{market_end.strftime('%Y-%m-%d %H:%M %Z')}"

    response = connection.get("stocks/#{symbol}/bars", params)
    @last_response = response
    
    if response.success?
      result = JSON.parse(response.body)
      
      # Update error message to be more informative
      if result["bars"] && result["bars"].any?
        latest_timestamp = Time.parse(result["bars"].last["t"]) rescue nil
        if latest_timestamp
          age_hours = ((Time.current - latest_timestamp) / 3600).round(1)
          @last_error = "Using most recent available data (#{age_hours} hours old) due to subscription limits on real-time data."
          Rails.logger.info @last_error
        end
      end
      
      result
    else
      @last_error = "Fallback failed - Alpaca Data Error (#{response.status}): #{response.body}"
      Rails.logger.error(@last_error)
      nil
    end
  end
end 