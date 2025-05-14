namespace :trading_bot do
  desc "Run the EMA trading bot (fetch data, check signals, execute trades)"
  task run: :environment do
    symbol = ENV.fetch("DEFAULT_SYMBOL", "AAPL")
    timeframe = ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
    
    puts "Starting EMA trading bot for #{symbol} with #{timeframe} timeframe..."
    
    bot = TradingBotService.new(symbol, timeframe)
    if bot.run
      puts "Trading bot completed successfully."
    else
      puts "Trading bot encountered an error: #{bot.last_error}"
    end
  end
  
  desc "Fetch EMA data without executing trades"
  task fetch_data: :environment do
    symbol = ENV.fetch("DEFAULT_SYMBOL", "AAPL")
    timeframe = ENV.fetch("DEFAULT_TIMEFRAME", "5Min")
    
    puts "Fetching EMA data for #{symbol} with #{timeframe} timeframe..."
    
    service = AlpacaDataService.new
    data = service.fetch_ema_data(symbol, timeframe: timeframe)
    
    if data
      closes = data[:closes]
      puts "Retrieved #{closes.length} candles"
      puts "Last 5 closes: #{closes.last(5).join(', ')}"
      
      # Calculate and display EMAs
      emas = EmaCalculatorService.calculate_emas(closes)
      puts "EMA-5: #{emas[:ema5].round(2)}"
      puts "EMA-8: #{emas[:ema8].round(2)}"
      puts "EMA-22: #{emas[:ema22].round(2)}"
      
      # Show trend information
      if EmaCalculatorService.uptrend?(emas[:ema5], emas[:ema8], emas[:ema22])
        puts "UPTREND: EMA-5 > EMA-8 > EMA-22"
      else
        puts "NOT IN UPTREND"
      end
    else
      puts "Error fetching data: #{service.last_error}"
    end
  end
end 