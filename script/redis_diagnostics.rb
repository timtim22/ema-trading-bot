#!/usr/bin/env ruby

require_relative '../config/environment'

puts "🔍 Redis Connection Diagnostics"
puts "=" * 50

# Check environment
puts "Environment: #{Rails.env}"
puts "Redis URL: #{ENV['REDIS_URL'] ? 'Present' : 'Missing'}"
if ENV['REDIS_URL']
  # Sanitize URL for display (hide credentials)
  sanitized_url = ENV['REDIS_URL'].gsub(/\/\/.*@/, '//***@')
  puts "Redis URL (sanitized): #{sanitized_url}"
end
puts ""

# Test Sidekiq Redis connection
puts "🔧 Testing Sidekiq Redis Connection..."
begin
  Sidekiq.redis { |conn| 
    response = conn.ping
    puts "✅ Sidekiq Redis: Connected (#{response})"
    
    # Test some basic operations
    conn.set('test_key', 'test_value')
    value = conn.get('test_key')
    conn.del('test_key')
    
    puts "✅ Sidekiq Redis: Read/Write operations working"
  }
rescue => e
  puts "❌ Sidekiq Redis: Connection failed"
  puts "   Error: #{e.message}"
  puts "   Error class: #{e.class}"
end
puts ""

# Test Rails cache (Redis)
puts "🗂️  Testing Rails Cache (Redis)..."
begin
  Rails.cache.write('test_cache_key', 'test_cache_value')
  value = Rails.cache.read('test_cache_key')
  Rails.cache.delete('test_cache_key')
  
  if value == 'test_cache_value'
    puts "✅ Rails Cache: Working correctly"
  else
    puts "⚠️  Rails Cache: Unexpected value returned"
  end
rescue => e
  puts "❌ Rails Cache: Connection failed"
  puts "   Error: #{e.message}"
  puts "   Error class: #{e.class}"
end
puts ""

# Test ActionCable (Redis)
puts "📡 Testing ActionCable (Redis)..."
begin
  # This is a bit more complex to test, so we'll just check if the adapter is configured
  cable_config = Rails.application.config_for(:cable)
  puts "✅ ActionCable: Configured with #{cable_config['adapter']} adapter"
  
  if cable_config['adapter'] == 'redis'
    puts "✅ ActionCable: Using Redis adapter"
  else
    puts "⚠️  ActionCable: Not using Redis adapter (#{cable_config['adapter']})"
  end
rescue => e
  puts "❌ ActionCable: Configuration error"
  puts "   Error: #{e.message}"
end
puts ""

# Test basic Redis operations with raw Redis client
puts "🔌 Testing Raw Redis Connection..."
begin
  require 'redis'
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  redis = Redis.new(url: redis_url)
  
  pong = redis.ping
  puts "✅ Raw Redis: Connected (#{pong})"
  
  redis.set('diagnostic_test', Time.current.to_s)
  value = redis.get('diagnostic_test')
  redis.del('diagnostic_test')
  
  puts "✅ Raw Redis: Read/Write operations working"
  puts "   Test value: #{value}"
rescue => e
  puts "❌ Raw Redis: Connection failed"
  puts "   Error: #{e.message}"
  puts "   Error class: #{e.class}"
end
puts ""

# Check Sidekiq jobs
puts "💼 Checking Sidekiq Job Status..."
begin
  require 'sidekiq/api'
  
  stats = Sidekiq::Stats.new
  puts "✅ Sidekiq Stats accessible"
  puts "   Enqueued: #{stats.enqueued}"
  puts "   Failed: #{stats.failed}"
  puts "   Processed: #{stats.processed}"
  
  scheduled = Sidekiq::ScheduledSet.new
  puts "   Scheduled jobs: #{scheduled.size}"
  
rescue => e
  puts "❌ Sidekiq API: Not accessible"
  puts "   Error: #{e.message}"
end
puts ""

puts "🎯 Summary:"
puts "- If all tests pass ✅, your Redis configuration is working correctly"
puts "- If tests fail ❌, check your REDIS_URL environment variable"
puts "- Make sure your Redis service is running and accessible"
puts "- In production, verify the Redis service is properly provisioned" 