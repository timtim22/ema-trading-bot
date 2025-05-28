namespace :positions do
  desc "Create test positions for demonstration"
  task create_test: :environment do
    # Find the first user or create one
    user = User.first
    unless user
      puts "No users found. Creating a test user..."
      user = User.create!(
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      puts "Created test user: #{user.email}"
    end
    
    # Create test positions using real Alpaca data
    test_positions = [
      {
        symbol: 'AAPL',
        amount: 1000.00,
        take_profit_percent: 2.0,  # 2% profit target
        stop_loss_percent: 1.5     # 1.5% stop loss
      },
      {
        symbol: 'MSFT',
        amount: 2000.00,
        take_profit_percent: 1.5,
        stop_loss_percent: 1.0
      },
      {
        symbol: 'TSLA',
        amount: 1500.00,
        take_profit_percent: 3.0,
        stop_loss_percent: 2.0
      }
    ]
    
    puts "Creating test positions with real Alpaca market data..."
    
    test_positions.each do |pos_data|
      puts "\nCreating position for #{pos_data[:symbol]}..."
      
      # Use PositionService to create positions with real market prices
      position = PositionService.create_position(user, {
        symbol: pos_data[:symbol],
        amount: pos_data[:amount]
      })
      
      if position
        # Calculate take profit and stop loss based on current market price
        current_price = position.entry_price
        take_profit_price = current_price * (1 + pos_data[:take_profit_percent] / 100.0)
        stop_loss_price = current_price * (1 - pos_data[:stop_loss_percent] / 100.0)
        
        # Update position with calculated levels
        position.update!(
          take_profit: take_profit_price.round(2),
          stop_loss: stop_loss_price.round(2),
          entry_time: Time.current - rand(1..24).hours
        )
        
        puts "✓ Created position: #{position.symbol}"
        puts "  Entry Price: $#{position.entry_price}"
        puts "  Current Price: $#{position.current_price}"
        puts "  Take Profit: $#{position.take_profit}"
        puts "  Stop Loss: $#{position.stop_loss}"
        puts "  P/L: #{position.formatted_pnl}"
      else
        puts "✗ Failed to create position for #{pos_data[:symbol]}"
      end
    end
    
    puts "\n" + "="*50
    puts "Test positions created successfully!"
    puts "You can now view them at http://localhost:3000/dashboard"
    puts "="*50
  end
  
  desc "Create a real trading position (uses Alpaca API)"
  task :create_real, [:symbol, :amount] => :environment do |t, args|
    symbol = args[:symbol] || 'AAPL'
    amount = args[:amount]&.to_f || 100.0
    
    user = User.first
    unless user
      puts "No users found. Please create a user first."
      exit 1
    end
    
    puts "Creating real trading position for #{symbol} with $#{amount}..."
    puts "This will place actual orders via Alpaca API!"
    
    # Confirm with user
    print "Are you sure? (y/N): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'y' || confirmation == 'yes'
      puts "Cancelled."
      exit 0
    end
    
    position = PositionService.create_trading_position(
      user, 
      symbol, 
      amount,
      take_profit_percent: 2.0,
      stop_loss_percent: 1.5
    )
    
    if position
      puts "✓ Real trading position created!"
      puts "  Position ID: #{position.id}"
      puts "  Symbol: #{position.symbol}"
      puts "  Amount: $#{position.amount}"
      puts "  Status: #{position.status}"
      if position.primary_order_id
        puts "  Alpaca Order ID: #{position.primary_order_id}"
      end
    else
      puts "✗ Failed to create real trading position"
    end
  end
  
  desc "Clear all test positions"
  task clear_test: :environment do
    count = Position.count
    Position.destroy_all
    puts "Cleared #{count} positions"
  end
end 