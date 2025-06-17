#!/usr/bin/env ruby
# Quick testing script for EMA Trading Bot core logic
# Usage: Run in Rails console with: load 'script/test_core_logic.rb'

puts "🚀 EMA Trading Bot Core Logic Tests"
puts "=" * 50

# Setup test user
user = User.first || User.create!(email: "test@example.com", password: "password123")
puts "✓ Test user: #{user.email}"

# Test 1: EMA Calculations
puts "\n📊 Test 1: EMA Calculations"
puts "-" * 30

trading_service = TradingBotService.new("AAPL", "5Min", user)
test_closes = [150.0, 151.0, 152.0, 151.5, 152.5, 153.0, 152.0, 153.5, 154.0, 155.0, 
               156.0, 157.0, 158.0, 159.0, 160.0, 159.5, 160.5, 161.0, 162.0, 163.0, 
               164.0, 165.0]

ema_result = trading_service.calculate_emas(test_closes)
if ema_result
  puts "EMA-5:  #{ema_result[:ema5].round(2)}"
  puts "EMA-8:  #{ema_result[:ema8].round(2)}"
  puts "EMA-22: #{ema_result[:ema22].round(2)}"
  
  uptrend = EmaCalculatorService.uptrend?(ema_result[:ema5], ema_result[:ema8], ema_result[:ema22])
  puts "Uptrend: #{uptrend ? '✓' : '✗'} #{uptrend}"
  
  # Validate EMA ordering for uptrend
  if ema_result[:ema5] > ema_result[:ema8] && ema_result[:ema8] > ema_result[:ema22]
    puts "✓ EMA ordering correct (EMA-5 > EMA-8 > EMA-22)"
  else
    puts "✗ EMA ordering incorrect"
  end
else
  puts "✗ EMA calculation failed"
end

# Test 2: Crossover Detection
puts "\n🔄 Test 2: Crossover Detection"
puts "-" * 30

crossover_data = [
  # Declining phase
  100.0, 99.8, 99.5, 99.2, 99.0, 98.8, 98.5, 98.2, 98.0, 97.8,
  97.5, 97.2, 97.0, 96.8, 96.5, 96.2, 96.0,
  # Rising phase - should trigger crossover
  96.5, 97.0, 98.0, 99.5, 101.0, 103.0
]

ema_data = trading_service.calculate_emas(crossover_data)
if ema_data
  crossover = EmaCalculatorService.confirmed_crossover?(ema_data[:ema5_values], ema_data[:ema8_values])
  puts "Crossover confirmed: #{crossover ? '✓' : '✗'} #{crossover}"
  
  puts "Last 3 EMA-5 values: #{ema_data[:ema5_values].last(3).map { |v| v.round(2) }}"
  puts "Last 3 EMA-8 values: #{ema_data[:ema8_values].last(3).map { |v| v.round(2) }}"
else
  puts "✗ Crossover data calculation failed"
end

# Test 3: Market Hours Detection
puts "\n🕐 Test 3: Market Hours Detection"
puts "-" * 30

# Test current time
current_error = trading_service.check_market_hours
if current_error
  puts "Current time: ✗ #{current_error}"
else
  puts "Current time: ✓ Market is OPEN"
end

# Test a known weekend (using Time.zone for consistency)
weekend_time = Time.zone.parse("2024-01-06 10:00:00") # Saturday
original_time = Time.current
Time.zone.stubs(:now).returns(weekend_time) if defined?(Mocha)

begin
  # Create new service instance to test weekend
  weekend_service = TradingBotService.new("AAPL", "5Min", user)
  
  # Mock Time.current for this test
  allow(Time).to receive(:current).and_return(weekend_time) if defined?(RSpec)
  
  weekend_error = weekend_service.check_market_hours
  puts "Weekend test: #{weekend_error ? '✓' : '✗'} #{weekend_error || 'Unexpected: market open'}"
rescue => e
  puts "Weekend test: ⚠️  Could not mock time (#{e.message})"
end

# Test 4: Risk Management Settings
puts "\n💰 Test 4: Risk Management"
puts "-" * 30

# Update user settings if possible
begin
  if user.respond_to?(:bot_setting)
    bot_setting = user.bot_setting || user.build_bot_setting
    bot_setting.update!(
      profit_percentage: 2.0,
      loss_percentage: 1.5,
      confirmation_bars: 2
    )
    puts "✓ User settings updated"
  else
    puts "⚠️  BotSetting model not available, using ENV defaults"
  end
rescue => e
  puts "⚠️  Could not update settings: #{e.message}"
end

new_service = TradingBotService.new("AAPL", "5Min", user)
profit_pct = new_service.instance_variable_get(:@profit_percentage)
loss_pct = new_service.instance_variable_get(:@loss_percentage)
confirmation = new_service.instance_variable_get(:@confirmation_bars)
trade_amount = new_service.instance_variable_get(:@trade_amount)

puts "Profit target: #{(profit_pct * 100).round(1)}%"
puts "Stop loss: #{(loss_pct * 100).round(1)}%"
puts "Confirmation bars: #{confirmation}"
puts "Trade amount: $#{trade_amount}"

# Test 5: Position Management Logic
puts "\n📈 Test 5: Position Logic"
puts "-" * 30

# Test profit calculation
entry_price = 150.0
current_price = 153.0
profit_pct = (current_price - entry_price) / entry_price
puts "Entry: $#{entry_price}, Current: $#{current_price}"
puts "Profit: #{(profit_pct * 100).round(2)}%"

# Check if this would trigger profit taking
user_profit_threshold = new_service.instance_variable_get(:@profit_percentage)
should_take_profit = profit_pct >= user_profit_threshold
puts "Should take profit: #{should_take_profit ? '✓' : '✗'} (threshold: #{(user_profit_threshold * 100).round(1)}%)"

# Test loss calculation
loss_price = 147.75
loss_pct = (loss_price - entry_price) / entry_price
puts "\nLoss scenario - Entry: $#{entry_price}, Current: $#{loss_price}"
puts "Loss: #{(loss_pct * 100).round(2)}%"

user_loss_threshold = new_service.instance_variable_get(:@loss_percentage)
should_stop_loss = loss_pct <= -user_loss_threshold
puts "Should stop loss: #{should_stop_loss ? '✓' : '✗'} (threshold: -#{(user_loss_threshold * 100).round(1)}%)"

# Test 6: Edge Cases
puts "\n⚠️  Test 6: Edge Cases"
puts "-" * 30

# Insufficient data
insufficient_data = [100.0, 101.0, 102.0]
edge_result = trading_service.calculate_emas(insufficient_data)
puts "Insufficient data handled: #{edge_result.nil? ? '✓' : '✗'} (returned #{edge_result.class})"

# Flat market
flat_data = Array.new(25, 100.0)
flat_result = trading_service.calculate_emas(flat_data)
if flat_result
  flat_uptrend = EmaCalculatorService.uptrend?(flat_result[:ema5], flat_result[:ema8], flat_result[:ema22])
  flat_crossover = EmaCalculatorService.confirmed_crossover?(flat_result[:ema5_values], flat_result[:ema8_values])
  puts "Flat market - No uptrend: #{!flat_uptrend ? '✓' : '✗'}"
  puts "Flat market - No crossover: #{!flat_crossover ? '✓' : '✗'}"
else
  puts "✗ Flat market test failed"
end

# Summary
puts "\n🎯 Demo-Ready Quick Test"
puts "=" * 50

demo_data = [145, 146, 147, 146, 148, 149, 147, 150, 151, 149, 152, 153, 151, 154, 155, 153, 156, 157, 155, 158, 160, 162]
demo_emas = trading_service.calculate_emas(demo_data)

if demo_emas
  demo_uptrend = EmaCalculatorService.uptrend?(demo_emas[:ema5], demo_emas[:ema8], demo_emas[:ema22])
  demo_crossover = EmaCalculatorService.confirmed_crossover?(demo_emas[:ema5_values], demo_emas[:ema8_values])
  
  puts "📊 Current EMAs:"
  puts "   EMA-5:  #{demo_emas[:ema5].round(2)}"
  puts "   EMA-8:  #{demo_emas[:ema8].round(2)}"
  puts "   EMA-22: #{demo_emas[:ema22].round(2)}"
  puts ""
  puts "🔍 Signal Analysis:"
  puts "   Uptrend:   #{demo_uptrend ? '✓' : '✗'} #{demo_uptrend}"
  puts "   Crossover: #{demo_crossover ? '✓' : '✗'} #{demo_crossover}"
  puts ""
  puts "📈 Trade Decision: #{demo_uptrend && demo_crossover ? '🟢 BUY SIGNAL' : '🔴 WAIT'}"
  puts ""
  puts "⚖️  Risk Parameters:"
  puts "   Profit Target: +#{(profit_pct * 100).round(1)}%"
  puts "   Stop Loss:     -#{(loss_pct * 100).round(1)}%"
  puts "   Trade Amount:  $#{trade_amount}"
  puts "   Confirmation:  #{confirmation} bars"
end

puts "\n✅ Core Logic Testing Complete!"
puts "Ready for client demo 🚀" 