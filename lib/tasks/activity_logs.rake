namespace :activity_logs do
  desc "Generate sample activity logs for testing"
  task create_sample: :environment do
    puts "Creating sample activity logs..."
    
    user = User.first
    symbols = ['AAPL', 'NVDA', 'MSFT', 'TSLA', 'GOOG', 'AMZN']
    
    # Create various types of activity logs
    50.times do |i|
      time_offset = rand(1..7).days.ago + rand(0..24).hours
      symbol = symbols.sample
      
      case rand(1..8)
      when 1..2 # Market data fetches
        ActivityLog.log_fetch(
          symbol,
          success: [true, true, true, false].sample,
          message: "Market data fetched for #{symbol}",
          user: [user, nil].sample,
          details: {
            timeframe: ['5m', '15m', '1h', '1d'].sample,
            bars_count: rand(10..100),
            source: 'alpaca'
          }
        )
        
      when 3 # Trading signals
        signal_type = ['buy', 'sell'].sample
        price = 100 + rand(0..500)
        
        ActivityLog.log_signal(
          symbol,
          signal_type,
          price,
          user: user,
          details: {
            ema5: price + rand(-5..5),
            ema8: price + rand(-8..8),
            ema22: price + rand(-15..15),
            confidence: rand(0.6..0.95).round(2)
          }
        )
        
      when 4 # Orders
        order_type = ['buy', 'sell'].sample
        amount = [100, 500, 1000, 2000].sample
        success = [true, true, false].sample
        
        ActivityLog.log_order(
          symbol,
          order_type,
          amount,
          success: success,
          message: success ? "#{order_type.upcase} order placed successfully" : "#{order_type.upcase} order failed",
          user: user,
          details: {
            price: 100 + rand(0..500),
            shares: (amount / (100 + rand(0..500))).round(2),
            order_id: "ORD-#{SecureRandom.hex(8)}",
            reason: success ? nil : ['Insufficient funds', 'Market closed', 'Invalid symbol'].sample
          }
        )
        
      when 5 # Errors
        error_messages = [
          'Failed to connect to Alpaca API',
          'Rate limit exceeded',
          'Invalid API credentials',
          'Network timeout',
          'Database connection error'
        ]
        
        ActivityLog.log_error(
          error_messages.sample,
          context: 'trading_bot',
          user: [user, nil].sample,
          details: {
            error_code: rand(400..599),
            retries: rand(0..3),
            component: ['api_client', 'database', 'signal_generator', 'order_service'].sample
          }
        )
        
      when 6 # Bot events
        action = ['start', 'stop'].sample
        ActivityLog.log_bot_event(
          action,
          user: user,
          message: "Trading bot #{action}ed by user",
          details: {
            reason: action == 'stop' ? ['manual', 'error', 'scheduled'].sample : 'manual',
            uptime: action == 'stop' ? "#{rand(1..48)} hours" : nil
          }
        )
        
      when 7 # Position events
        action = ['open', 'close'].sample
        ActivityLog.log_position_event(
          action,
          symbol,
          user: user,
          details: {
            amount: [100, 500, 1000, 2000].sample,
            price: 100 + rand(0..500),
            reason: action == 'close' ? ['take_profit', 'stop_loss', 'manual'].sample : nil,
            profit_loss: action == 'close' ? rand(-500..1000) : nil
          }
        )
        
      when 8 # Market updates
        price = 100 + rand(0..500)
        ActivityLog.log_market_update(
          symbol,
          price,
          user: nil,
          details: {
            change: rand(-10..10).round(2),
            change_percent: rand(-5..5).round(2),
            volume: rand(1000000..50000000),
            last_updated: Time.current.iso8601
          }
        )
      end
      
      # Update the created_at and occurred_at to simulate historical data
      activity = ActivityLog.last
      activity.update_columns(
        created_at: time_offset,
        updated_at: time_offset,
        occurred_at: time_offset
      )
    end
    
    puts "✅ Created #{ActivityLog.count} activity logs"
    puts "📊 Breakdown:"
    ActivityLog::TYPES.each do |type|
      count = ActivityLog.where(event_type: type).count
      puts "   #{type}: #{count}" if count > 0
    end
  end
  
  desc "Clear all activity logs"
  task clear: :environment do
    count = ActivityLog.count
    ActivityLog.delete_all
    puts "🧹 Cleared #{count} activity logs"
  end
  
  desc "Show activity log statistics"
  task stats: :environment do
    puts "📊 Activity Log Statistics:"
    puts "Total logs: #{ActivityLog.count}"
    puts ""
    
    puts "By Type:"
    ActivityLog::TYPES.each do |type|
      count = ActivityLog.where(event_type: type).count
      puts "  #{type.humanize}: #{count}" if count > 0
    end
    puts ""
    
    puts "By Level:"
    ActivityLog::LEVELS.each do |level|
      count = ActivityLog.where(level: level).count
      puts "  #{level.humanize}: #{count}" if count > 0
    end
    puts ""
    
    puts "Recent Activity (last 10):"
    ActivityLog.recent.limit(10).each do |log|
      puts "  [#{log.level.upcase}] #{log.event_type}: #{log.message[0..60]}#{'...' if log.message.length > 60}"
    end
  end
end 