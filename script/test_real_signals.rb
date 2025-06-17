#!/usr/bin/env ruby
# Script to test real signal detection with actual EMA calculations
# Usage: Run in Rails console with: load 'script/test_real_signals.rb'

puts "🔄 Testing Real Signal Detection Logic"
puts "=" * 50

user = User.first || User.create!(email: "test@example.com", password: "password123")
symbol = "TSLA"  # Use current symbol you're testing

puts "✓ Test user: #{user.email}"
puts "✓ Test symbol: #{symbol}"

# Test 1: Simulate EMA crossover from bearish to bullish
puts "\n📈 Test 1: Bullish Crossover Signal"
puts "-" * 40

# Create previous EMAs (bearish alignment)
previous_emas = {
  ema5: 347.5,   # EMA5 < EMA8 (bearish)
  ema8: 348.0,
  ema22: 348.3
}

# Create current EMAs (bullish alignment) 
current_emas = {
  ema5: 348.5,   # EMA5 > EMA8 > EMA22 (bullish crossover)
  ema8: 348.2,
  ema22: 347.8
}

current_price = 348.2

puts "Previous EMAs: 5=#{previous_emas[:ema5]}, 8=#{previous_emas[:ema8]}, 22=#{previous_emas[:ema22]}"
puts "Current EMAs:  5=#{current_emas[:ema5]}, 8=#{current_emas[:ema8]}, 22=#{current_emas[:ema22]}"

# Test signal detection
signal = TradingSignal.detect_crossover_signal(
  symbol, 
  current_emas, 
  previous_emas, 
  current_price, 
  user
)

if signal
  puts "✅ BUY Signal Detected!"
  puts "   Signal Type: #{signal.signal_type}"
  puts "   Price: $#{signal.price}"
  puts "   EMAs: #{signal.ema5}/#{signal.ema8}/#{signal.ema22}"
  puts "   Time: #{signal.formatted_time}"
else
  puts "✗ No signal detected"
end

# Test 2: Simulate EMA crossover from bullish to bearish
puts "\n📉 Test 2: Bearish Crossover Signal"
puts "-" * 40

# Create previous EMAs (bullish alignment)
previous_emas_bull = {
  ema5: 348.5,   # EMA5 > EMA8 > EMA22 (bullish)
  ema8: 348.2,
  ema22: 347.8
}

# Create current EMAs (bearish alignment)
current_emas_bear = {
  ema5: 347.5,   # EMA5 < EMA8 < EMA22 (bearish crossover)
  ema8: 347.8,
  ema22: 348.1
}

current_price_bear = 347.5

puts "Previous EMAs: 5=#{previous_emas_bull[:ema5]}, 8=#{previous_emas_bull[:ema8]}, 22=#{previous_emas_bull[:ema22]}"
puts "Current EMAs:  5=#{current_emas_bear[:ema5]}, 8=#{current_emas_bear[:ema8]}, 22=#{current_emas_bear[:ema22]}"

# Test signal detection
signal_bear = TradingSignal.detect_crossover_signal(
  symbol, 
  current_emas_bear, 
  previous_emas_bull, 
  current_price_bear, 
  user
)

if signal_bear
  puts "✅ SELL Signal Detected!"
  puts "   Signal Type: #{signal_bear.signal_type}"
  puts "   Price: $#{signal_bear.price}"
  puts "   EMAs: #{signal_bear.ema5}/#{signal_bear.ema8}/#{signal_bear.ema22}"
  puts "   Time: #{signal_bear.formatted_time}"
else
  puts "✗ No signal detected"
end

# Test 3: No crossover (continuation)
puts "\n➡️  Test 3: No Crossover (Continuation)"
puts "-" * 40

# Both previous and current are bullish (no crossover)
continuation_emas = {
  ema5: 348.6,   # Still bullish, no crossover
  ema8: 348.3,
  ema22: 347.9
}

puts "Previous EMAs: 5=#{current_emas[:ema5]}, 8=#{current_emas[:ema8]}, 22=#{current_emas[:ema22]}"
puts "Current EMAs:  5=#{continuation_emas[:ema5]}, 8=#{continuation_emas[:ema8]}, 22=#{continuation_emas[:ema22]}"

signal_cont = TradingSignal.detect_crossover_signal(
  symbol, 
  continuation_emas, 
  current_emas, 
  348.5, 
  user
)

if signal_cont
  puts "✗ Unexpected signal detected: #{signal_cont.signal_type}"
else
  puts "✅ No signal detected (correct - no crossover)"
end

# Test 4: Real Market Data Signal Detection
puts "\n🔄 Test 4: Simulate MarketPingJob Signal Detection"
puts "-" * 50

# Simulate what MarketPingJob does
begin
  puts "Simulating MarketPingJob logic..."
  
  # Create market data similar to what MarketPingJob generates
  market_data = {
    price: 348.2,
    emas: current_emas,
    source: 'test_simulation'
  }
  
  # Store previous EMAs (simulate what MarketPingJob does)
  @test_previous_emas = previous_emas
  
  # Simulate the detect_and_broadcast_signals method
  if @test_previous_emas
    test_signal = TradingSignal.detect_crossover_signal(
      symbol, 
      market_data[:emas], 
      @test_previous_emas, 
      market_data[:price], 
      user
    )
    
    if test_signal
      puts "🚨 MarketPingJob would detect: #{test_signal.signal_type.upcase} signal!"
      puts "   This would broadcast to: trading_signals_user_#{user.id}"
      puts "   And trigger UI notification"
      
      # Show what the broadcast would contain
      broadcast_data = {
        type: "trading_signal",
        signal: {
          id: test_signal.id,
          symbol: test_signal.symbol,
          signal_type: test_signal.signal_type,
          price: test_signal.price.to_f,
          ema5: test_signal.ema5.to_f,
          ema8: test_signal.ema8.to_f,
          ema22: test_signal.ema22.to_f,
          timestamp: test_signal.timestamp.to_i,
          formatted_time: test_signal.formatted_time,
          formatted_price: test_signal.formatted_price,
          signal_description: test_signal.signal_description,
          badge_class: test_signal.signal_badge_class
        }
      }
      
      puts "\n📡 Broadcast Data:"
      puts "   Channel: trading_signals_user_#{user.id}"
      puts "   Type: #{broadcast_data[:type]}"
      puts "   Signal: #{broadcast_data[:signal][:signal_description]}"
      puts "   Price: #{broadcast_data[:signal][:formatted_price]}"
    else
      puts "✗ No signal would be detected"
    end
  end
  
rescue => e
  puts "❌ Error in simulation: #{e.message}"
end

# Summary
puts "\n📊 Signal Detection Summary"
puts "=" * 50
puts "Total signals created: #{TradingSignal.where(user: user, symbol: symbol).count}"
puts "Recent signals:"

TradingSignal.where(user: user, symbol: symbol).recent_first.limit(3).each do |s|
  puts "  • #{s.signal_icon} #{s.signal_type.upcase} @ #{s.formatted_price} (#{s.formatted_time})"
end

puts "\n✅ Real Signal Detection Testing Complete!"
puts "\n🎯 For UI Testing:"
puts "1. Keep bot running and wait for natural crossovers"
puts "2. Watch browser console for signal notifications"
puts "3. Check 'Trading Signals' section in dashboard"
puts "4. Look for chart markers when signals appear" 