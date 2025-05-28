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
    # Use historical data from a specific time range that should be accessible
    # Common free tier allows access to data that's not recent
    if from.nil? && to.nil?
      # Use data from 2023 which should be accessible on most plans
      to = "2025-05-28T16:00:00Z"
      from = "2025-05-27T09:30:00Z"
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
      JSON.parse(response.body)
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
end 