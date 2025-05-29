namespace :trading_history do
  desc "Create test trading history data"
  task create_test_data: :environment do
    user = User.first
    unless user
      puts "No users found. Please create a user first."
      exit 1
    end
    
    puts "Creating test trading history for #{user.email}..."
    puts "=" * 50
    
    # Define test trades with various outcomes
    test_trades = [
      # Profitable trades
      { symbol: 'AAPL', entry_price: 180.00, exit_price: 185.50, amount: 1000, exit_reason: 'take_profit', days_ago: 1 },
      { symbol: 'NVDA', entry_price: 480.00, exit_price: 495.20, amount: 500, exit_reason: 'take_profit', days_ago: 2 },
      { symbol: 'MSFT', entry_price: 370.00, exit_price: 378.15, amount: 800, exit_reason: 'take_profit', days_ago: 3 },
      { symbol: 'TSLA', entry_price: 240.00, exit_price: 248.80, amount: 600, exit_reason: 'take_profit', days_ago: 5 },
      { symbol: 'GOOG', entry_price: 170.00, exit_price: 174.25, amount: 700, exit_reason: 'take_profit', days_ago: 7 },
      
      # Loss trades
      { symbol: 'AAPL', entry_price: 185.00, exit_price: 181.75, amount: 900, exit_reason: 'stop_loss', days_ago: 4 },
      { symbol: 'NVDA', entry_price: 490.00, exit_price: 485.20, amount: 400, exit_reason: 'stop_loss', days_ago: 6 },
      { symbol: 'AMZN', entry_price: 178.00, exit_price: 175.50, amount: 550, exit_reason: 'stop_loss', days_ago: 8 },
      
      # Manual closes
      { symbol: 'MSFT', entry_price: 375.00, exit_price: 377.80, amount: 750, exit_reason: 'manual_close', days_ago: 9 },
      { symbol: 'TSLA', entry_price: 245.00, exit_price: 242.10, amount: 650, exit_reason: 'manual_close', days_ago: 10 },
      
      # More historical data
      { symbol: 'AAPL', entry_price: 175.00, exit_price: 179.25, amount: 1200, exit_reason: 'take_profit', days_ago: 15 },
      { symbol: 'NVDA', entry_price: 470.00, exit_price: 465.80, amount: 300, exit_reason: 'stop_loss', days_ago: 18 },
      { symbol: 'GOOG', entry_price: 168.00, exit_price: 171.50, amount: 850, exit_reason: 'take_profit', days_ago: 20 },
      { symbol: 'AMZN', entry_price: 180.00, exit_price: 183.60, amount: 600, exit_reason: 'take_profit', days_ago: 22 },
      { symbol: 'MSFT', entry_price: 365.00, exit_price: 362.75, amount: 700, exit_reason: 'stop_loss', days_ago: 25 },
      
      # Older trades for pagination testing
      { symbol: 'AAPL', entry_price: 170.00, exit_price: 173.40, amount: 1000, exit_reason: 'take_profit', days_ago: 30 },
      { symbol: 'TSLA', entry_price: 235.00, exit_price: 231.50, amount: 500, exit_reason: 'stop_loss', days_ago: 35 },
      { symbol: 'NVDA', entry_price: 460.00, exit_price: 468.20, amount: 400, exit_reason: 'take_profit', days_ago: 40 },
      { symbol: 'GOOG', entry_price: 165.00, exit_price: 162.25, amount: 800, exit_reason: 'stop_loss', days_ago: 45 },
      { symbol: 'AMZN', entry_price: 175.00, exit_price: 178.75, amount: 650, exit_reason: 'take_profit', days_ago: 50 }
    ]
    
    created_count = 0
    
    test_trades.each do |trade_data|
      puts "\nCreating #{trade_data[:exit_reason]} trade for #{trade_data[:symbol]}..."
      
      # Calculate entry and exit times
      entry_time = trade_data[:days_ago].days.ago + rand(1..8).hours
      exit_time = entry_time + rand(30.minutes..6.hours)
      
      # Calculate shares and profit/loss
      shares = trade_data[:amount] / trade_data[:entry_price]
      entry_value = trade_data[:amount]
      exit_value = shares * trade_data[:exit_price]
      profit_loss = exit_value - entry_value
      
      # Determine status based on profit/loss
      status = profit_loss > 0 ? 'closed_profit' : 'closed_loss'
      
      # Create the position
      position = user.positions.create!(
        symbol: trade_data[:symbol],
        amount: trade_data[:amount],
        entry_price: trade_data[:entry_price],
        exit_price: trade_data[:exit_price],
        entry_time: entry_time,
        exit_time: exit_time,
        exit_reason: trade_data[:exit_reason],
        status: status,
        profit_loss: profit_loss
      )
      
      if position.persisted?
        puts "✓ Created #{trade_data[:symbol]} trade:"
        puts "  Entry: $#{trade_data[:entry_price]} → Exit: $#{trade_data[:exit_price]}"
        puts "  P/L: #{profit_loss >= 0 ? '+' : ''}$#{profit_loss.round(2)} (#{((profit_loss / entry_value) * 100).round(2)}%)"
        puts "  Shares: #{shares.round(4)}"
        puts "  Exit Reason: #{trade_data[:exit_reason]}"
        puts "  Date: #{exit_time.strftime('%m/%d/%Y %I:%M %p')}"
        created_count += 1
      else
        puts "✗ Failed to create #{trade_data[:symbol]} trade: #{position.errors.full_messages.join(', ')}"
      end
    end
    
    puts "\n" + "=" * 50
    puts "Created #{created_count} test trading history records!"
    puts "Total completed trades for #{user.email}: #{user.positions.completed.count}"
    puts "Total profit/loss: $#{user.positions.completed.sum(:profit_loss).round(2)}"
    puts "Win rate: #{((user.positions.where(status: 'closed_profit').count.to_f / user.positions.completed.count) * 100).round(2)}%"
    puts "\nYou can now view the trading history at:"
    puts "http://localhost:3000/trades/history"
    puts "=" * 50
  end
  
  desc "Clear all test trading history"
  task clear_test_data: :environment do
    count = Position.completed.count
    Position.completed.destroy_all
    puts "Cleared #{count} completed positions from trading history"
  end
end 