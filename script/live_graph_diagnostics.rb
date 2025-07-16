#!/usr/bin/env ruby

require_relative '../config/environment'

puts "🔍 Live Graph Diagnostics"
puts "=" * 50

# Test 1: Check if Sidekiq is working
puts "\n1️⃣ Testing Sidekiq Background Jobs..."
begin
  # Queue a simple test job
  test_job = MarketPingJob.perform_later('AAPL')
  puts "✅ Sidekiq: Test job queued successfully"
  puts "   Job ID: #{test_job.job_id}"
  
  # Check Sidekiq stats
  require 'sidekiq/api'
  stats = Sidekiq::Stats.new
  puts "   Enqueued jobs: #{stats.enqueued}"
  puts "   Failed jobs: #{stats.failed}"
  puts "   Processed jobs: #{stats.processed}"
  
rescue => e
  puts "❌ Sidekiq: Error queuing job"
  puts "   Error: #{e.message}"
end

# Test 2: Check bot states
puts "\n2️⃣ Checking Bot States..."
begin
  BotState.all.each do |state|
    puts "📊 #{state.symbol}: #{state.running? ? '🟢 Running' : '🔴 Stopped'}"
    puts "   Last run: #{state.last_run_at || 'Never'}"
    puts "   Error: #{state.error_message}" if state.error_message.present?
  end
rescue => e
  puts "❌ Error checking bot states: #{e.message}"
end

# Test 3: Test ActionCable broadcasting
puts "\n3️⃣ Testing ActionCable Broadcasting..."
begin
  test_message = {
    type: "test_broadcast",
    symbol: "AAPL",
    timestamp: Time.current.to_i,
    message: "Test broadcast from diagnostics script"
  }
  
  # Try to broadcast to all users
  User.find_each do |user|
    ActionCable.server.broadcast("market_channel_#{user.id}", test_message)
    puts "✅ ActionCable: Broadcasted test message to user #{user.email}"
  end
  
rescue => e
  puts "❌ ActionCable: Error broadcasting"
  puts "   Error: #{e.message}"
end

# Test 4: Check Redis connection for ActionCable
puts "\n4️⃣ Testing ActionCable Redis Connection..."
begin
  cable_config = Rails.application.config_for(:cable)
  puts "📡 ActionCable adapter: #{cable_config['adapter']}"
  
  if cable_config['adapter'] == 'redis'
    redis_url = cable_config['url']
    puts "📡 ActionCable Redis URL: #{redis_url.gsub(/\/\/.*@/, '//***@')}"
    
    # Test Redis connection
    require 'redis'
    redis = Redis.new(url: redis_url)
    response = redis.ping
    puts "✅ ActionCable Redis: Connected (#{response})"
  else
    puts "⚠️  ActionCable: Not using Redis adapter"
  end
  
rescue => e
  puts "❌ ActionCable Redis: Connection failed"
  puts "   Error: #{e.message}"
end

# Test 5: Check user configurations
puts "\n5️⃣ Checking User Symbol Configurations..."
begin
  User.find_each do |user|
    symbols = user.configured_symbols rescue []
    puts "👤 #{user.email}: #{symbols.any? ? symbols.join(', ') : 'No symbols configured'}"
  end
rescue => e
  puts "❌ Error checking user configurations: #{e.message}"
end

# Test 6: Manual market data fetch
puts "\n6️⃣ Testing Manual Market Data Fetch..."
begin
  symbol = 'AAPL'
  puts "📊 Fetching market data for #{symbol}..."
  
  # Use the same method as MarketPingJob
  market_data_service = MarketDataService.new
  price_data = MarketDataService.get_current_price(symbol)
  
  puts "✅ Market data fetched successfully"
  puts "   Price: $#{price_data[:price]}"
  puts "   Source: #{price_data[:source]}"
  
rescue => e
  puts "❌ Market data fetch failed"
  puts "   Error: #{e.message}"
end

puts "\n🎯 Live Graph Troubleshooting Steps:"
puts "1. If Sidekiq jobs are failing, check REDIS_URL environment variable"
puts "2. If bot states are stopped, start them from the dashboard"
puts "3. If ActionCable broadcasting fails, check Redis connection"
puts "4. If user has no symbols configured, add symbols in Symbol Management"
puts "5. Check browser console for JavaScript errors"
puts "6. Verify WebSocket connection in browser Network tab"

puts "\n🔧 Quick Fixes to Try:"
puts "- Restart the bot from dashboard: /dashboard"
puts "- Check browser console for 'Connected to MarketChannel' message"
puts "- Verify REDIS_URL environment variable is set correctly"
puts "- Test WebSocket connection manually in browser console:"
puts "  window.marketChannel (should be defined)"

puts "\n💡 Browser Debug Commands:"
puts "- Open browser console on your dashboard"
puts "- Check: window.marketChannel"
puts "- Check: document.querySelector('[data-controller*=\"chart\"]')"
puts "- Listen for events: document.addEventListener('market:ping', (e) => console.log('Market ping:', e.detail))" 