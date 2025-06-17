#!/usr/bin/env ruby
# Simple script to run paper trading for demonstration

puts "🚀 EMA Trading Bot - Paper Trading Runner"
puts "=" * 50

require_relative '../config/environment'

def start_paper_trading
  puts "\n📊 Starting Paper Trading Demo..."
  
  # Verify paper trading mode
  unless PaperTradingService.paper_trading_enabled?
    puts "❌ Error: Not in paper trading mode!"
    puts "💡 Set PAPER_TRADING=true in your environment"
    return
  end
  
  puts "✅ Paper Trading Mode: ACTIVE"
  
  # Get current account status
  paper_service = PaperTradingService.new
  account_info = paper_service.get_paper_account_info
  
  if account_info
    puts "\n💰 Current Account Status:"
    puts "   Portfolio Value: $#{account_info[:portfolio_value]}"
    puts "   Buying Power: $#{account_info[:buying_power]}"
    puts "   Day Trades Used: #{account_info[:day_trade_count] || 0}"
  end
  
  # Show current positions
  positions = paper_service.get_paper_positions
  if positions && positions.any?
    puts "\n📊 Current Positions:"
    positions.each do |pos|
      puts "   #{pos[:symbol]}: #{pos[:qty]} shares (P/L: $#{pos[:unrealized_pl]})"
    end
  else
    puts "\n📊 No current positions"
  end
  
  puts "\n🤖 Starting Bot Activity..."
  
  # Start bots for configured symbols
  symbols = User.first&.configured_symbols || ['TSLA', 'AAPL']
  
  symbols.each do |symbol|
    puts "\n📈 Processing #{symbol}..."
    
    begin
      # Start bot state
      bot_state = BotState.find_or_create_by(symbol: symbol)
      bot_state.update!(running: true, last_run_at: Time.current, error_message: nil)
      
      # Run market analysis
      MarketPingJob.perform_now(symbol)
      
      puts "   ✅ Bot started for #{symbol}"
      puts "   📊 Market data processed"
      
    rescue => e
      puts "   ❌ Error with #{symbol}: #{e.message}"
    end
    
    # Small delay between symbols
    sleep(1)
  end
  
  puts "\n🎯 Paper Trading Status:"
  puts "   • Bots running for: #{symbols.join(', ')}"
  puts "   • Mode: Paper Trading (Simulation)"
  puts "   • Market data: Real-time from Alpaca"
  puts "   • Risk: ZERO (fake money only)"
  
  puts "\n📋 Next Steps:"
  puts "   1. Let bots run during market hours (9:30 AM - 4:00 PM EST)"
  puts "   2. Generate logs: ruby script/client_verification_log.rb"
  puts "   3. Check dashboard: http://localhost:3000/dashboard"
  puts "   4. View paper trading details: http://localhost:3000/dashboard/paper_trading_details"
  
  puts "\n⏰ Current Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  puts "📍 Market Status: #{market_status}"
  
end

def market_status
  now = Time.current
  
  # Convert to EST (market timezone)
  est_time = now.in_time_zone('America/New_York')
  
  # Check if it's a weekday
  return "CLOSED (Weekend)" if est_time.saturday? || est_time.sunday?
  
  # Check market hours (9:30 AM - 4:00 PM EST)
  market_open = est_time.beginning_of_day + 9.hours + 30.minutes
  market_close = est_time.beginning_of_day + 16.hours
  
  if est_time >= market_open && est_time <= market_close
    "OPEN (#{est_time.strftime('%H:%M EST')})"
  else
    "CLOSED (#{est_time.strftime('%H:%M EST')} - Opens at 09:30 EST)"
  end
end

def show_paper_trading_commands
  puts "\n📚 Paper Trading Commands:"
  puts "=" * 30
  puts "Start paper trading:     ruby script/run_paper_trading.rb"
  puts "Generate client logs:    ruby script/client_verification_log.rb"
  puts "Simulate activity:       ruby script/generate_trading_logs.rb simulate"
  puts "Full simulation + logs:  ruby script/generate_trading_logs.rb both"
  puts ""
  puts "Dashboard URLs:"
  puts "Main dashboard:          http://localhost:3000/dashboard"
  puts "Paper trading details:   http://localhost:3000/dashboard/paper_trading_details"
  puts ""
  puts "Files for client:"
  puts "• client_verification_*.txt  (send this to client)"
  puts "• trading_log_*.txt          (detailed activity logs)"
  puts "• paper_trading_report_*.txt (performance reports)"
end

# Main execution
if ARGV[0] == 'help'
  show_paper_trading_commands
else
  start_paper_trading
  puts "\n💡 Run 'ruby script/run_paper_trading.rb help' to see all commands"
end 