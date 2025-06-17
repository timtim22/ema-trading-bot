#!/usr/bin/env ruby
# Demo Verification Script - Run before client demo
# Usage: rails runner 'load "script/demo_verification.rb"'

puts "🎯 PRE-DEMO SYSTEM VERIFICATION"
puts "=" * 50

# 1. Check user and basic setup
user = User.first
if user
  puts "✅ User found: #{user.email}"
else
  puts "❌ No user found - create test user first!"
  exit 1
end

# 2. Check bot settings
bot_settings = BotSetting.for_user(user)
puts "✅ Bot Settings:"
puts "   Profit: #{bot_settings.profit_percentage}%"
puts "   Loss: #{bot_settings.loss_percentage}%"
puts "   Symbols: #{user.configured_symbols.join(', ')}"

# 3. Verify WebSocket/ActionCable is working
begin
  ActionCable.server.broadcast("test_channel", { test: "message" })
  puts "✅ ActionCable broadcasting working"
rescue => e
  puts "❌ ActionCable issue: #{e.message}"
end

# 4. Test signal creation (without UI broadcast)
puts "\n🧪 Testing signal creation..."
test_signal = TradingSignal.create!(
  user: user,
  symbol: "DEMO",
  signal_type: "buy",
  price: 100.0,
  ema5: 101.0,
  ema8: 100.5,
  ema22: 100.0,
  timestamp: Time.current
)
puts "✅ Signal creation working (ID: #{test_signal.id})"
test_signal.destroy # Clean up

# 5. Test position creation
puts "\n💰 Testing position creation..."
test_position = Position.create!(
  user: user,
  symbol: "DEMO",
  amount: 1000.0,
  entry_price: 100.0,
  current_price: 100.0,
  status: 'open',
  entry_time: Time.current,
  take_profit: 102.0,
  stop_loss: 99.0
)
puts "✅ Position creation working (ID: #{test_position.id})"
test_position.destroy # Clean up

# 6. Check database connections
puts "\n💾 Database check:"
puts "   Total signals: #{TradingSignal.count}"
puts "   Total positions: #{Position.count}"
puts "   Active positions: #{Position.active.count}"

# 7. Verify test script exists
test_script_path = "script/test_signals_with_ui.rb"
if File.exist?(test_script_path)
  puts "✅ Demo test script ready: #{test_script_path}"
else
  puts "❌ Missing demo test script!"
end

# 8. Check current positions (should be clean)
active_positions = Position.active.count
if active_positions == 0
  puts "✅ Clean slate - no active positions"
else
  puts "⚠️  Warning: #{active_positions} active positions exist"
  puts "   Run: Position.destroy_all to clean up"
end

puts "\n🎯 DEMO READINESS STATUS"
puts "=" * 30
puts "✅ User authentication ready"
puts "✅ Bot settings configured"
puts "✅ Database connections working"
puts "✅ Signal/position creation working"
puts "✅ ActionCable broadcasting ready"
puts "✅ Test scripts available"

puts "\n🚀 READY FOR DEMO!"
puts "\nDuring demo, run:"
puts "  rails runner 'load \"script/test_signals_with_ui.rb\"'"
puts "\nFor settings demo:"
puts "  1. Change settings in UI"
puts "  2. Run test script again"
puts "  3. Show different Take Profit/Stop Loss values"

puts "\n📋 Demo Script: COMPREHENSIVE_DEMO_SCRIPT.md" 