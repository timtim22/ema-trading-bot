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
  def fetch_bars(symbol, timeframe: "5Min", limit: 50, from: '2025-05-13T13:25:00Z', to: '2025-05-13T14:30:00Z')
    params = { timeframe: timeframe, limit: limit }
    params[:start] = from if from
    params[:end] = to if to

    response = connection.get("stocks/#{symbol}/bars", params)
    @last_response = response
    
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
  def fetch_closes(symbol, timeframe: "5Min", limit: 22)
    data = fetch_bars(symbol, timeframe: timeframe, limit: limit)
    return nil unless data
    
    data.fetch("bars", []).map { |bar| bar["c"] }
  end
  
  # Fetch EMA data for a symbol
  # Note: This simply returns the raw closing prices - EMAs need to be calculated or obtained elsewhere
  #
  # @param symbol [String] the stock symbol (e.g., "AAPL") 
  # @param timeframe [String] the time interval (e.g., "5Min", "1D")
  # @return [Hash, nil] hash with closes array, or nil on failure
  def fetch_ema_data(symbol, timeframe: "5Min")
    # We need at least 22 bars to calculate EMA-22, plus additional for more accuracy
    # Adding extra bars for more accurate calculation
    closes = fetch_closes(symbol, timeframe: timeframe, limit: 50)
    return nil unless closes
    
    {
      symbol: symbol,
      timeframe: timeframe,
      closes: closes,
      timestamp: Time.current
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
  
  private
  
  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.headers["APCA-API-KEY-ID"] = @api_key_id
      f.headers["APCA-API-SECRET-KEY"] = @api_secret_key
      f.adapter Faraday.default_adapter
    end
  end
end 