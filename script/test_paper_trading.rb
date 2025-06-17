#!/usr/bin/env ruby
# Test script for paper trading functionality

puts "🧾 EMA Trading Bot - Paper Trading Test"
puts "=" * 50

# Load Rails environment
require_relative '../config/environment'

# Test trading mode
puts "\n📊 Trading Mode Information:"
mode_info = PaperTradingService.get_trading_mode_info
mode_info.each do |key, value|
  puts "  #{key}: #{value}"
end

puts "\n🔍 Environment Validation:"
validation = PaperTradingService.validate_paper_environment
validation.each do |key, value|
  next if key == :warnings && value.empty?
  next if key == :errors && value.empty?
  
  puts "  #{key}: #{value}"
end

unless validation[:warnings].empty?
  puts "\n⚠️  Warnings:"
  validation[:warnings].each { |w| puts "  - #{w}" }
end

unless validation[:errors].empty?
  puts "\n❌ Errors:"
  validation[:errors].each { |e| puts "  - #{e}" }
end

# Test paper trading service if enabled
if PaperTradingService.paper_trading_enabled?
  puts "\n💰 Paper Trading Account Test:"
  
  begin
    paper_service = PaperTradingService.new
    
    # Get account info
    account_info = paper_service.get_paper_account_info
    if account_info
      puts "  ✅ Account Status: #{account_info[:status]}"
      puts "  💵 Cash: $#{account_info[:cash].round(2)}"
      puts "  📈 Portfolio Value: $#{account_info[:portfolio_value].round(2)}"
      puts "  💳 Buying Power: $#{account_info[:buying_power].round(2)}"
      puts "  🔢 Day Trade Count: #{account_info[:day_trade_count]}"
    else
      puts "  ❌ Failed to get account info: #{paper_service.last_error}"
    end
    
    # Get positions
    positions = paper_service.get_paper_positions
    puts "  📊 Active Positions: #{positions.count}"
    positions.first(3).each do |pos|
      puts "    #{pos[:symbol]}: #{pos[:qty]} shares, P&L: $#{pos[:unrealized_pl].round(2)}"
    end
    
    # Get recent orders
    orders = paper_service.get_paper_orders(limit: 5)
    puts "  📋 Recent Orders: #{orders.count}"
    orders.first(3).each do |order|
      puts "    #{order[:symbol]} #{order[:side]} #{order[:qty]} @ #{order[:status]}"
    end
    
    # Get performance
    performance = paper_service.calculate_paper_performance
    if performance.any?
      puts "  📈 Performance Metrics:"
      puts "    Total Return: #{performance[:total_return_percent]}%"
      puts "    Win Rate: #{performance[:win_rate]}%"
      puts "    Total Trades: #{performance[:total_trades]}"
    end
    
  rescue => e
    puts "  ❌ Error testing paper trading: #{e.message}"
  end
else
  puts "\n⚠️  Paper trading is not enabled!"
  puts "   Set PAPER_TRADING=true to enable paper trading mode."
end

puts "\n🚀 Test Complete!"
puts "\nNext Steps:"
puts "1. Ensure your ALPACA_API_KEY_ID and ALPACA_API_SECRET_KEY are set"
puts "2. Get paper trading keys from: https://app.alpaca.markets/paper/dashboard/overview"
puts "3. Start your bot and monitor paper trading performance"
puts "4. Only switch to live trading after successful paper testing!" 