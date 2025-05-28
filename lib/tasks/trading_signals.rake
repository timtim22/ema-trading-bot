namespace :trading_signals do
  desc "Create test trading signals"
  task create_test: :environment do
    puts "🚨 Creating test trading signals..."
    
    user = User.first
    unless user
      puts "❌ No users found. Please create a user first."
      exit 1
    end
    
    symbols = %w[AAPL MSFT GOOG AMZN TSLA NVDA]
    signal_types = %w[buy sell]
    
    5.times do |i|
      symbol = symbols.sample
      signal_type = signal_types.sample
      
      # Generate realistic EMA values
      base_price = case symbol
      when 'AAPL' then 185.0
      when 'MSFT' then 375.0
      when 'GOOG' then 171.0
      when 'AMZN' then 178.0
      when 'TSLA' then 241.0
      when 'NVDA' then 875.0
      else 100.0
      end
      
      price = base_price + (rand(-10.0..10.0))
      ema5 = price + (rand(-2.0..2.0))
      ema8 = price + (rand(-3.0..3.0))
      ema22 = price + (rand(-5.0..5.0))
      
      signal = TradingSignal.create!(
        user: user,
        symbol: symbol,
        signal_type: signal_type,
        price: price.round(2),
        ema5: ema5.round(2),
        ema8: ema8.round(2),
        ema22: ema22.round(2),
        timestamp: Time.current - (i * 10).minutes
      )
      
      puts "✅ Created #{signal_type} signal for #{symbol} at $#{signal.price}"
    end
    
    puts "🎉 Created #{TradingSignal.count} total trading signals"
  end
  
  desc "Clear all test trading signals"
  task clear_test: :environment do
    puts "🗑️  Clearing all trading signals..."
    count = TradingSignal.count
    TradingSignal.destroy_all
    puts "✅ Cleared #{count} trading signals"
  end
  
  desc "Simulate real-time trading signals"
  task simulate_realtime: :environment do
    puts "🔄 Starting real-time trading signal simulation..."
    puts "Press Ctrl+C to stop"
    
    user = User.first
    unless user
      puts "❌ No users found. Please create a user first."
      exit 1
    end
    
    symbols = %w[AAPL MSFT GOOG]
    
    trap("INT") do
      puts "\n👋 Stopping simulation..."
      exit 0
    end
    
    loop do
      symbol = symbols.sample
      signal_type = %w[buy sell].sample
      
      # Generate realistic market data
      base_price = case symbol
      when 'AAPL' then 185.0 + rand(-5.0..5.0)
      when 'MSFT' then 375.0 + rand(-8.0..8.0)
      when 'GOOG' then 171.0 + rand(-3.0..3.0)
      end
      
      price = base_price.round(2)
      ema5 = (price + rand(-1.0..1.0)).round(2)
      ema8 = (price + rand(-2.0..2.0)).round(2)
      ema22 = (price + rand(-3.0..3.0)).round(2)
      
      # Create signal
      signal = TradingSignal.create!(
        user: user,
        symbol: symbol,
        signal_type: signal_type,
        price: price,
        ema5: ema5,
        ema8: ema8,
        ema22: ema22,
        timestamp: Time.current
      )
      
      puts "🚨 #{Time.current.strftime('%H:%M:%S')} - #{signal_type.upcase} signal: #{symbol} @ $#{price}"
      
      # Broadcast the signal
      ActionCable.server.broadcast("trading_signals_user_#{user.id}", {
        type: "trading_signal",
        signal: {
          id: signal.id,
          symbol: signal.symbol,
          signal_type: signal.signal_type,
          price: signal.price.to_f,
          ema5: signal.ema5.to_f,
          ema8: signal.ema8.to_f,
          ema22: signal.ema22.to_f,
          timestamp: signal.timestamp.to_i,
          formatted_time: signal.formatted_time,
          formatted_price: signal.formatted_price,
          signal_description: signal.signal_description,
          badge_class: signal.signal_badge_class
        }
      })
      
      # Wait 15-30 seconds before next signal
      sleep(rand(15..30))
    end
  end
  
  desc "Show recent trading signals"
  task show: :environment do
    puts "📊 Recent Trading Signals:"
    puts "=" * 80
    
    TradingSignal.recent_first.limit(10).each do |signal|
      icon = signal.buy_signal? ? "📈" : "📉"
      puts "#{icon} #{signal.formatted_date_time} | #{signal.symbol} | #{signal.signal_type.upcase} @ #{signal.formatted_price} | EMAs: #{signal.ema5}/#{signal.ema8}/#{signal.ema22}"
    end
    
    if TradingSignal.count == 0
      puts "No trading signals found. Run 'rails trading_signals:create_test' to create some."
    end
  end
end 