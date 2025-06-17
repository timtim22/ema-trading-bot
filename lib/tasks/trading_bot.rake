namespace :trading_bot do
  desc "Run the EMA trading bot (fetch data, check signals, execute trades)"
  task run: :environment do
    symbols = ENV.fetch("WATCH_SYMBOLS", "AAPL,MSFT,GOOGL").split(',')
    timeframe = ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
    
    puts "Starting EMA trading bot for #{symbols.length} symbols: #{symbols.join(', ')}"
    puts "Using #{timeframe} timeframe"
    
    # Get the default user for automated trades
    default_user = User.find_by(email: ENV.fetch("DEFAULT_USER_EMAIL", nil)) || User.first
    
    symbols.each do |symbol|
      puts "Processing symbol: #{symbol}"
      bot = TradingBotService.new(symbol, timeframe, default_user)
      
      if bot.run(async: false)  # Use synchronous execution for rake tasks
        puts "Trading bot completed successfully for #{symbol}."
      else
        puts "Trading bot encountered an error for #{symbol}: #{bot.last_error}"
      end
    end
  end
  
  desc "Fetch data without executing trades"
  task fetch_data: :environment do
    symbols = ENV.fetch("WATCH_SYMBOLS", "AAPL").split(',')
    timeframe = ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
    
    symbols.each do |symbol|
      puts "Fetching data for #{symbol} with #{timeframe} timeframe..."
      
      service = AlpacaDataService.new
      data = service.fetch_closes_with_timestamp(symbol, timeframe: timeframe)
      
      if data
        closes = data[:closes]
        puts "Retrieved #{closes.length} candles"
        puts "Last 5 closes: #{closes.last(5).join(', ')}"
        
        # Calculate and display EMAs
        ema_data = EmaCalculatorService.calculate_ema_series(closes)
        puts "EMA-5: #{ema_data[5]&.round(2)}"
        puts "EMA-8: #{ema_data[8]&.round(2)}"
        puts "EMA-22: #{ema_data[22]&.round(2)}"
        
        # Show trend information
        if ema_data[5] && ema_data[8] && ema_data[22] && 
           EmaCalculatorService.uptrend?(ema_data[5], ema_data[8], ema_data[22])
          puts "UPTREND: EMA-5 > EMA-8 > EMA-22"
        else
          puts "NOT IN UPTREND"
        end
      else
        puts "Error fetching data for #{symbol}"
      end
      
      puts "----------------------------"
    end
  end
end 