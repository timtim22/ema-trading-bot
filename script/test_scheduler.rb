#!/usr/bin/env ruby
# Test script for scheduler functionality

puts "Testing Sidekiq-cron scheduler setup..."

# Check if we're in Rails environment
unless defined?(Rails)
  puts "Loading Rails environment..."
  require_relative '../config/environment'
end

puts "\n1. Checking Sidekiq connection..."
begin
  Sidekiq.redis { |conn| conn.ping }
  puts "✅ Sidekiq connected to Redis successfully"
rescue => e
  puts "❌ Sidekiq connection failed: #{e.message}"
  exit 1
end

puts "\n2. Checking scheduled jobs..."
jobs = Sidekiq::Cron::Job.all
if jobs.any?
  puts "✅ Found #{jobs.count} scheduled jobs:"
  jobs.each do |job|
    puts "  - #{job.name}: #{job.cron} (#{job.klass})"
  end
else
  puts "❌ No scheduled jobs found"
end

puts "\n3. Testing SymbolManagementJob..."
begin
  SymbolManagementJob.perform_now
  puts "✅ SymbolManagementJob executed successfully"
rescue => e
  puts "❌ SymbolManagementJob failed: #{e.message}"
end

puts "\n4. Testing MarketPingJob..."
begin
  MarketPingJob.perform_now("AAPL")
  puts "✅ MarketPingJob executed successfully"
rescue => e
  puts "❌ MarketPingJob failed: #{e.message}"
end

puts "\n5. Checking job queue..."
stats = Sidekiq::Stats.new
puts "✅ Queue stats:"
puts "  - Processed: #{stats.processed}"
puts "  - Failed: #{stats.failed}"
puts "  - Enqueued: #{stats.enqueued}"

puts "\nScheduler test completed!"
