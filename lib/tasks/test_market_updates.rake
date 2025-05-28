namespace :test do
  desc "Send test market updates to simulate real-time price changes"
  task market_updates: :environment do
    puts "Starting test market updates..."
    puts "This will send price updates every 3 seconds for AAPL, MSFT, and TSLA"
    puts "Press Ctrl+C to stop"
    
    # Base prices
    prices = {
      'AAPL' => 198.0,
      'MSFT' => 375.22,
      'TSLA' => 241.35
    }
    
    begin
      loop do
        # Update each symbol with a small random change
        prices.each do |symbol, base_price|
          # Generate a small price change (-1% to +1%)
          change_percent = (rand - 0.5) * 2.0
          new_price = base_price * (1.01 + change_percent / 100.0)
          new_price = [new_price, 1.0].max.round(2)
          
          # Update the base price for next iteration
          prices[symbol] = new_price
          
          # Broadcast the update
          ActionCable.server.broadcast('market_channel', {
            type: 'market_update',
            symbol: symbol,
            price: new_price,
            timestamp: Time.current.to_i,
            source: 'test'
          })
          
          puts "#{Time.current.strftime('%H:%M:%S')} - #{symbol}: $#{new_price}"
        end
        
        puts "---"
        sleep 3
      end
    rescue Interrupt
      puts "\nStopped test market updates"
    end
  end
  
  desc "Send a single test market update"
  task :single_update, [:symbol, :price] => :environment do |t, args|
    symbol = args[:symbol] || 'AAPL'
    price = args[:price]&.to_f || (190 + rand * 20).round(2)
    
    ActionCable.server.broadcast('market_channel', {
      type: 'market_update',
      symbol: symbol,
      price: price,
      timestamp: Time.current.to_i,
      source: 'test'
    })
    
    puts "Sent test update: #{symbol} @ $#{price}"
  end
end 