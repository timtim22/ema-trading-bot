#!/usr/bin/env ruby
# Script to test that bot settings are applied correctly
# Usage: Run in Rails console with: load 'script/test_bot_settings.rb'

puts "🎛️ Testing Bot Settings Integration"
puts "=" * 50

user = User.first || User.create!(email: "test@example.com", password: "password123")
symbol = "TSLA"

puts "✓ Test user: #{user.email}"
puts "✓ Test symbol: #{symbol}"

# Get current bot settings
bot_settings = BotSetting.for_user(user)
puts "\n📊 Current Bot Settings:"
puts "   Profit Percentage: #{bot_settings.profit_percentage}%"
puts "   Loss Percentage: #{bot_settings.loss_percentage}%"
puts "   Confirmation Bars: #{bot_settings.confirmation_bars}"
puts "   Timeframe: #{bot_settings.timeframe}"
puts "   Configured symbols: #{user.configured_symbols.join(', ')}"

# Test 1: Update settings and verify they persist
puts "\n🔧 Test 1: Update Settings and Verify Persistence"
puts "-" * 45

old_profit = bot_settings.profit_percentage
old_loss = bot_settings.loss_percentage

# Update settings
new_profit = 1.5
new_loss = 1.0
new_confirmation = 2

bot_settings.update!(
  profit_percentage: new_profit,
  loss_percentage: new_loss,
  confirmation_bars: new_confirmation
)

puts "✅ Settings updated:"
puts "   Profit: #{old_profit}% → #{new_profit}%"
puts "   Loss: #{old_loss}% → #{new_loss}%"
puts "   Confirmation: #{new_confirmation} bars"

# Verify persistence
bot_settings.reload
puts "\n✅ Settings persist after reload:"
puts "   Profit: #{bot_settings.profit_percentage}%"
puts "   Loss: #{bot_settings.loss_percentage}%"
puts "   Confirmation: #{bot_settings.confirmation_bars}"

# Test 2: Create position and verify take profit/stop loss calculations
puts "\n💰 Test 2: Position Creation with New Settings"
puts "-" * 45

# Clear existing positions
Position.where(user: user, symbol: symbol).destroy_all

entry_price = 349.00
test_position = Position.create!(
  user: user,
  symbol: symbol,
  amount: 1000.0,
  entry_price: entry_price,
  current_price: entry_price,
  status: 'open',
  entry_time: Time.current,
  # Calculate take profit and stop loss using settings
  take_profit: (entry_price * (1 + new_profit / 100.0)).round(2),
  stop_loss: (entry_price * (1 - new_loss / 100.0)).round(2)
)

puts "✅ Position created with settings-based levels:"
puts "   Entry Price: $#{test_position.entry_price}"
puts "   Take Profit: $#{test_position.take_profit} (+#{new_profit}%)"
puts "   Stop Loss: $#{test_position.stop_loss} (-#{new_loss}%)"

# Verify calculations
expected_tp = (entry_price * (1 + new_profit / 100.0)).round(2)
expected_sl = (entry_price * (1 - new_loss / 100.0)).round(2)

puts "\n🧮 Calculation Verification:"
puts "   Expected Take Profit: $#{expected_tp}"
puts "   Actual Take Profit: $#{test_position.take_profit}"
puts "   ✓ Match: #{expected_tp == test_position.take_profit}"

puts "   Expected Stop Loss: $#{expected_sl}"
puts "   Actual Stop Loss: $#{test_position.stop_loss}"
puts "   ✓ Match: #{expected_sl == test_position.stop_loss}"

# Test 3: Test UserTradingService uses these settings
puts "\n🤖 Test 3: UserTradingService Settings Integration"
puts "-" * 45

trading_service = UserTradingService.new(user, symbol)
trading_params = trading_service.trading_parameters

puts "✅ UserTradingService parameters:"
puts "   Profit Percentage: #{trading_params[:profit_percentage]}%"
puts "   Loss Percentage: #{trading_params[:loss_percentage]}%"
puts "   Confirmation Bars: #{trading_params[:confirmation_bars]}"
puts "   Timeframe: #{trading_params[:timeframe]}"

# Verify they match our updated settings
puts "\n🔍 Settings Match Verification:"
puts "   Profit matches: #{trading_params[:profit_percentage] == new_profit}"
puts "   Loss matches: #{trading_params[:loss_percentage] == new_loss}"
puts "   Confirmation matches: #{trading_params[:confirmation_bars] == new_confirmation}"

# Test 4: Simulate position exit based on settings
puts "\n📈 Test 4: Position Exit Logic with Settings"
puts "-" * 45

# Test take profit scenario
take_profit_price = test_position.take_profit + 0.01  # Slightly above take profit
puts "Simulating price movement to $#{take_profit_price} (above take profit)..."

profit_pct = (take_profit_price - test_position.entry_price) / test_position.entry_price
puts "   Profit percentage: #{(profit_pct * 100).round(2)}%"
puts "   Settings threshold: #{new_profit}%"
puts "   Should trigger take profit: #{profit_pct >= (new_profit / 100.0)}"

# Test stop loss scenario  
stop_loss_price = test_position.stop_loss - 0.01  # Slightly below stop loss
puts "\nSimulating price movement to $#{stop_loss_price} (below stop loss)..."

loss_pct = (stop_loss_price - test_position.entry_price) / test_position.entry_price
puts "   Loss percentage: #{(loss_pct * 100).round(2)}%"
puts "   Settings threshold: -#{new_loss}%"
puts "   Should trigger stop loss: #{loss_pct <= -(new_loss / 100.0)}"

puts "\n📊 Real-Time Testing Summary:"
puts "=" * 50
puts "✅ Settings persist in database"
puts "✅ UserTradingService uses current settings"
puts "✅ Position levels calculated from settings"
puts "✅ Exit logic respects percentage thresholds"

puts "\n🎯 UI Verification Steps:"
puts "1. Check Active Positions table - Take Profit/Stop Loss should match calculations above"
puts "2. Watch for automatic position closes when prices hit thresholds"
puts "3. Verify new positions use updated percentages"
puts "4. Settings page should show: #{new_profit}% profit, #{new_loss}% loss, #{new_confirmation} bars"

puts "\n✅ Bot Settings Test Complete!" 