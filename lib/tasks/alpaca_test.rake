namespace :alpaca do
  desc "Test Alpaca API connection and configuration"
  task test: :environment do
    puts "🔍 Testing Alpaca API Connection"
    puts "=" * 50
    
    # Check environment variables
    puts "Environment: #{Rails.env}"
    puts "Paper Trading: #{ENV.fetch('PAPER_TRADING', 'true')}"
    puts "Alpaca Endpoint: #{defined?(ALPACA_ENDPOINT) ? ALPACA_ENDPOINT : 'Not defined'}"
    puts ""
    
    # Check credentials
    key_id = ENV['ALPACA_API_KEY_ID']
    key_secret = ENV['ALPACA_API_SECRET_KEY']
    
    puts "Credentials Check:"
    puts "  API Key ID present: #{key_id.present?}"
    puts "  API Key ID length: #{key_id&.length}"
    puts "  API Key ID first 4 chars: #{key_id&.first(4)}"
    puts "  Secret Key present: #{key_secret.present?}"
    puts "  Secret Key length: #{key_secret&.length}"
    puts ""
    
    if !key_id.present? || !key_secret.present?
      puts "❌ Missing credentials - cannot test connection"
      exit 1
    end
    
    # Test AlpacaDataService
    puts "Testing AlpacaDataService:"
    begin
      service = AlpacaDataService.new
      
      if service.instance_variable_get(:@configuration_error)
        puts "❌ Configuration error: #{service.instance_variable_get(:@configuration_error)}"
        exit 1
      end
      
      puts "✅ Service initialized successfully"
      
      # Test basic connection
      puts "\nTesting basic API call (AAPL bars):"
      start_time = Time.current
      result = service.fetch_bars('AAPL', limit: 1)
      end_time = Time.current
      response_time = ((end_time - start_time) * 1000).round(2)
      
      puts "  Response time: #{response_time}ms"
      
      if result
        puts "✅ API call successful"
        puts "  Has bars: #{result['bars']&.any?}"
        puts "  Bars count: #{result['bars']&.length || 0}"
        
        if result['bars']&.any?
          bar = result['bars'].first
          puts "  Sample bar: #{bar['t']} - $#{bar['c']}"
        end
        
        # Check rate limits
        rate_info = service.rate_limit_info
        if rate_info[:remaining]
          puts "  Rate limit: #{rate_info[:remaining]}/#{rate_info[:limit]} remaining"
        end
        
      else
        puts "❌ API call failed"
        puts "  Error: #{service.last_error}"
        
        if service.last_response
          puts "  HTTP Status: #{service.last_response.status}"
          puts "  Response body: #{service.last_response.body[0..200]}..."
        end
      end
      
    rescue => e
      puts "❌ Exception during test: #{e.message}"
      puts "  Class: #{e.class.name}"
      puts "  Backtrace: #{e.backtrace.first(3).join("\n")}"
    end
    
    puts "\n" + "=" * 50
    puts "Test completed"
  end
end 