class MarketDataService
  # Real market data APIs you could integrate:
  # - Alpha Vantage (free tier available)
  # - IEX Cloud (free tier available)
  # - Polygon.io (free tier available)
  # - Yahoo Finance (unofficial)
  # - Finnhub (free tier available)
  # - Alpaca Markets API
  
  def self.get_real_price(symbol)
    case Rails.env
    when 'production'
      # In production, always try Alpaca first, then fallback to simulated
      alpaca_result = get_price_from_alpaca(symbol)
      if alpaca_result
        alpaca_result
      else
        Rails.logger.warn "MarketDataService: Falling back to simulated data for #{symbol} in production"
        get_simulated_price(symbol)
      end
    when 'development'
      # Use real Alpaca data in development too, with fallback to simulated
      get_price_from_alpaca(symbol) || get_simulated_price(symbol)
    else
      get_simulated_price(symbol)
    end
  end
  
  # Get current market price from Alpaca
  def self.get_current_price(symbol)
    get_real_price(symbol)
  end
  
  # Get OHLC data from Alpaca
  def self.get_ohlc_data(symbol, timeframe: '1Min', limit: 1)
    begin
      alpaca_service = AlpacaDataService.new
      
      # Get the most recent bar data
      data = alpaca_service.fetch_bars(symbol, timeframe: timeframe, limit: limit)
      
      if data && data['bars'] && data['bars'].any?
        bar = data['bars'].last
        
        {
          symbol: symbol,
          open: bar['o'].to_f,
          high: bar['h'].to_f,
          low: bar['l'].to_f,
          close: bar['c'].to_f,
          volume: bar['v'].to_i,
          timestamp: Time.parse(bar['t']),
          source: 'alpaca'
        }
      else
        Rails.logger.warn "MarketDataService: No OHLC data available for #{symbol}, using simulated"
        if alpaca_service.instance_variable_get(:@configuration_error)
          Rails.logger.warn "MarketDataService: Alpaca configuration issue for OHLC: #{alpaca_service.instance_variable_get(:@configuration_error)}"
        end
        get_simulated_ohlc(symbol)
      end
    rescue => e
      Rails.logger.error "MarketDataService: Error fetching OHLC data for #{symbol}: #{e.message}"
      Rails.logger.error "MarketDataService: #{e.backtrace.first(3).join("\n")}"
      get_simulated_ohlc(symbol)
    end
  end
  
  # Get historical data for EMA calculations
  def self.get_historical_closes(symbol, timeframe: '1Min', limit: 50)
    begin
      alpaca_service = AlpacaDataService.new
      
      closes_data = alpaca_service.fetch_closes_with_timestamp(symbol, timeframe: timeframe, limit: limit)
      
      if closes_data && closes_data[:closes]
        {
          symbol: symbol,
          closes: closes_data[:closes],
          timestamp: closes_data[:timestamp],
          source: 'alpaca'
        }
      else
        Rails.logger.warn "MarketDataService: No historical data available for #{symbol}, using simulated"
        if alpaca_service.instance_variable_get(:@configuration_error)
          Rails.logger.warn "MarketDataService: Alpaca configuration issue for historical data: #{alpaca_service.instance_variable_get(:@configuration_error)}"
        end
        get_simulated_historical(symbol, limit)
      end
    rescue => e
      Rails.logger.error "MarketDataService: Error fetching historical data for #{symbol}: #{e.message}"
      Rails.logger.error "MarketDataService: #{e.backtrace.first(3).join("\n")}"
      get_simulated_historical(symbol, limit)
    end
  end
  
  private
  
  # Example: Alpha Vantage API integration
  def self.get_price_from_api(symbol)
    api_key = Rails.application.credentials.alpha_vantage_api_key
    url = "https://www.alphavantage.co/query"
    
    params = {
      function: 'GLOBAL_QUOTE',
      symbol: symbol,
      apikey: api_key
    }
    
    begin
      response = HTTParty.get(url, query: params)
      data = response.parsed_response
      
      # Parse Alpha Vantage response
      quote = data['Global Quote']
      current_price = quote['05. price'].to_f
      
      {
        symbol: symbol,
        price: current_price,
        timestamp: Time.current,
        source: 'alpha_vantage'
      }
    rescue => e
      Rails.logger.error "MarketDataService: Error fetching real data for #{symbol}: #{e.message}"
      # Fallback to simulated data
      get_simulated_price(symbol)
    end
  end
  
  # Example: IEX Cloud API integration (alternative)
  def self.get_price_from_iex(symbol)
    api_key = Rails.application.credentials.iex_cloud_api_key
    url = "https://cloud.iexapis.com/stable/stock/#{symbol}/quote"
    
    begin
      response = HTTParty.get(url, query: { token: api_key })
      data = response.parsed_response
      
      {
        symbol: symbol,
        price: data['latestPrice'].to_f,
        timestamp: Time.current,
        source: 'iex_cloud'
      }
    rescue => e
      Rails.logger.error "MarketDataService: Error fetching IEX data for #{symbol}: #{e.message}"
      get_simulated_price(symbol)
    end
  end
  
  # Get current price from Alpaca API
  def self.get_price_from_alpaca(symbol)
    alpaca_service = AlpacaDataService.new
    
    begin
      # Get the most recent bar (1-minute data)
      data = alpaca_service.fetch_bars(symbol, timeframe: '1Min', limit: 1)
      
      if data && data['bars'] && data['bars'].any?
        latest_bar = data['bars'].last
        current_price = latest_bar['c'].to_f
        
        {
          symbol: symbol,
          price: current_price,
          timestamp: Time.parse(latest_bar['t']),
          source: 'alpaca'
        }
      else
        Rails.logger.warn "MarketDataService: No current price data for #{symbol} from Alpaca"
        if alpaca_service.instance_variable_get(:@configuration_error)
          Rails.logger.warn "MarketDataService: Alpaca configuration issue: #{alpaca_service.instance_variable_get(:@configuration_error)}"
        end
        nil
      end
    rescue => e
      Rails.logger.error "MarketDataService: Error fetching Alpaca data for #{symbol}: #{e.message}"
      Rails.logger.error "MarketDataService: #{e.backtrace.first(3).join("\n")}"
      nil
    end
  end
  
  # Keep simulated data for development/testing
  def self.get_simulated_price(symbol)
    base_prices = {
      "AAPL" => 185.5,
      "MSFT" => 402.5,
      "GOOG" => 171.2,
      "AMZN" => 178.3,
      "TSLA" => 248.5,
      "NVDA" => 875.2
    }
    
    base_price = base_prices[symbol] || 100.0
    
    # Simple random walk
    @last_prices ||= {}
    @last_prices[symbol] ||= base_price
    
    change_pct = (rand - 0.48) * 2 # Slight upward bias
    new_price = @last_prices[symbol] * (1 + change_pct / 100.0)
    new_price = [new_price, 1.0].max.round(2)
    
    @last_prices[symbol] = new_price
    
    {
      symbol: symbol,
      price: new_price,
      timestamp: Time.current,
      source: 'simulated'
    }
  end
  
  # Simulated OHLC data fallback
  def self.get_simulated_ohlc(symbol)
    price_data = get_simulated_price(symbol)
    current_price = price_data[:price]
    
    # Generate realistic OHLC around current price
    volatility = 0.005 # 0.5%
    range = current_price * volatility
    
    open = current_price + (rand - 0.5) * range
    close = current_price
    high = [open, close].max + rand * range
    low = [open, close].min - rand * range
    
    {
      symbol: symbol,
      open: open.round(2),
      high: high.round(2),
      low: low.round(2),
      close: close.round(2),
      volume: rand(100_000..2_000_000),
      timestamp: Time.current,
      source: 'simulated'
    }
  end
  
  # Simulated historical data fallback
  def self.get_simulated_historical(symbol, limit)
    base_price = get_simulated_price(symbol)[:price]
    closes = []
    
    limit.times do |i|
      change = (rand - 0.5) * 0.02 # ±1% change
      price = base_price * (1 + change)
      closes << price.round(2)
      base_price = price
    end
    
    {
      symbol: symbol,
      closes: closes,
      timestamp: Time.current,
      source: 'simulated'
    }
  end
  
  # Get multiple symbols at once (more efficient for real APIs)
  def self.get_multiple_prices(symbols)
    symbols.map { |symbol| get_real_price(symbol) }
  end
  
  # Get historical data for EMA calculations
  def self.get_historical_data(symbol, period = '1day', interval = '1min')
    # Implementation depends on your chosen API
    # This would return OHLC data for EMA calculations
  end
end 