#!/usr/bin/env ruby
# Demo script to simulate trading activity for client demonstration

puts "🎯 EMA Trading Bot - Demo Simulation"
puts "=" * 50

# Load Rails environment
require_relative '../config/environment'

def simulate_demo_trading
  puts "\n📊 Starting Paper Trading Demo Simulation..."
  
  # Verify we're in paper trading mode
  unless PaperTradingService.paper_trading_enabled?
    puts "❌ Error: Not in paper trading mode!"
    return
  end
  
  puts "✅ Confirmed: Paper Trading Mode Active"
  
  # Get initial account state
  paper_service = PaperTradingService.new
  initial_account = paper_service.get_paper_account_info
  
  if initial_account
    puts "\n💰 Initial Paper Account State:"
    puts "  Portfolio Value: $#{initial_account[:portfolio_value].to_f.round(2)}"
    puts "  Cash Balance: $#{initial_account[:cash_balance].to_f.round(2)}"
    puts "  Buying Power: $#{initial_account[:buying_power].to_f.round(2)}"
  end
  
  # Get market data for simulation
  puts "\n📈 Fetching Market Data for TSLA..."
  
  begin
    data_service = AlpacaDataService.new
    market_data = data_service.get_market_data('TSLA')
    
    if market_data
      puts "✅ Market Data Retrieved:"
      puts "  Current Price: $#{market_data[:current_price]}"
      puts "  EMA-5: #{market_data[:ema_5]}"
      puts "  EMA-8: #{market_data[:ema_8]}"
      
      # Simulate EMA crossover detection
      puts "\n🔍 Analyzing EMA Crossover Pattern..."
      
      ema_5 = market_data[:ema_5].to_f
      ema_8 = market_data[:ema_8].to_f
      
      if ema_5 > ema_8
        puts "📈 BULLISH SIGNAL: EMA-5 (#{ema_5.round(2)}) > EMA-8 (#{ema_8.round(2)})"
        signal_type = 'BUY'
      else
        puts "📉 BEARISH SIGNAL: EMA-5 (#{ema_5.round(2)}) < EMA-8 (#{ema_8.round(2)})"
        signal_type = 'SELL'
      end
      
      # Simulate placing a paper trade
      puts "\n🚀 Simulating Trade Execution..."
      
      order_service = OrderService.new
      
      if signal_type == 'BUY'
        puts "  Action: Placing $1,000 BUY order for TSLA"
        # In a real scenario, this would place an actual paper trade
        puts "  ✅ SIMULATED: Market buy order placed"
        puts "  📋 Order Details:"
        puts "    - Symbol: TSLA"
        puts "    - Side: BUY"
        puts "    - Type: MARKET"
        puts "    - Notional: $1,000"
        puts "    - Expected Shares: ~#{(1000 / market_data[:current_price].to_f).round(0)}"
      else
        puts "  Action: Would sell existing position (if any)"
        puts "  ℹ️  No existing position to sell in this demo"
      end
      
    else
      puts "❌ Could not retrieve market data"
    end
    
  rescue => e
    puts "⚠️  Error fetching market data: #{e.message}"
    puts "ℹ️  This is normal during market closed hours"
  end
  
  # Show paper trading performance metrics
  puts "\n📊 Paper Trading Performance Summary:"
  
  performance = paper_service.calculate_paper_performance
  if performance
    puts "  Total Trades: #{performance[:total_trades] || 0}"
    puts "  Winning Trades: #{performance[:winning_trades] || 0}"
    puts "  Losing Trades: #{performance[:losing_trades] || 0}"
    puts "  Win Rate: #{performance[:win_rate] || 0}%"
    puts "  Total Return: #{performance[:total_return_dollar] || 0}"
    puts "  Return Percentage: #{performance[:total_return_percent] || 0}%"
  end
  
  # Get current positions
  positions = paper_service.get_paper_positions
  if positions && positions.any?
    puts "\n💼 Current Positions:"
    positions.each do |position|
      puts "  #{position[:symbol]}: #{position[:qty]} shares (P/L: $#{position[:unrealized_pl]})"
    end
  else
    puts "\n💼 No Current Positions"
  end
  
  # Show recent orders
  recent_orders = paper_service.get_paper_orders(limit: 5)
  if recent_orders && recent_orders.any?
    puts "\n📋 Recent Orders:"
    recent_orders.each do |order|
      puts "  #{order[:created_at]} - #{order[:symbol]} #{order[:side].upcase} #{order[:status]}"
    end
  else
    puts "\n📋 No Recent Orders"
  end
  
  puts "\n" + "=" * 50
  puts "✅ Demo Simulation Complete!"
  puts "\nℹ️  Key Points for Your Client:"
  puts "   • All trades are simulated with fake money ($100,000 starting balance)"
  puts "   • Uses real market data from Alpaca"
  puts "   • EMA crossover strategy is fully automated"
  puts "   • Risk management with 1% stop-loss and take-profit"
  puts "   • Complete audit trail of all activities"
  puts "   • Can switch to live trading when ready"
  puts "\n🎯 Next Steps:"
  puts "   1. Let the bot run during market hours"
  puts "   2. Monitor performance in the dashboard"
  puts "   3. Export results to share with client"
  puts "   4. Switch to live trading when satisfied"
  
end

def generate_client_report
  puts "\n📄 Generating Client Report..."
  
  paper_service = PaperTradingService.new
  account_info = paper_service.get_paper_account_info
  performance = paper_service.calculate_paper_performance
  positions = paper_service.get_paper_positions
  
  report = <<~REPORT
    
    EMA TRADING BOT - PAPER TRADING DEMONSTRATION REPORT
    ===================================================
    Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
    
    STRATEGY OVERVIEW:
    -----------------
    • EMA 5-8 Crossover Strategy
    • $1,000 per trade position sizing
    • 1% stop-loss and take-profit levels
    • 3-bar confirmation to reduce false signals
    • Fully automated execution
    
    PAPER TRADING RESULTS:
    ---------------------
    Portfolio Value: $#{account_info ? account_info[:portfolio_value] : 'N/A'}
    Cash Balance: $#{account_info ? account_info[:cash_balance] : 'N/A'}
    
    Total Trades: #{performance ? performance[:total_trades] : 0}
    Winning Trades: #{performance ? performance[:winning_trades] : 0}
    Losing Trades: #{performance ? performance[:losing_trades] : 0}
    Win Rate: #{performance ? performance[:win_rate] : 0}%
    
    Total Return: $#{performance ? performance[:total_return_dollar] : 0}
    Return Percentage: #{performance ? performance[:total_return_percent] : 0}%
    
    CURRENT POSITIONS:
    -----------------
    #{positions && positions.any? ? positions.map { |p| "#{p[:symbol]}: #{p[:qty]} shares (P/L: $#{p[:unrealized_pl]})" }.join("\n") : "No current positions"}
    
    RISK MANAGEMENT:
    ---------------
    • Maximum risk per trade: 1% of position value
    • Automatic stop-loss orders
    • Position sizing based on available capital
    • Paper trading eliminates financial risk during testing
    
    NEXT STEPS:
    ----------
    1. Continue paper trading to gather more performance data
    2. Monitor strategy performance across different market conditions
    3. Fine-tune parameters if needed
    4. Transition to live trading when confident in results
    
    NOTE: This is simulated trading using paper money. No real funds are at risk.
    All market data and order executions are handled through Alpaca's paper trading environment.
    
  REPORT
  
  puts report
  
  # Save report to file
  filename = "paper_trading_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt"
  File.write(filename, report)
  puts "\n💾 Report saved as: #{filename}"
  
  return report
end

# Main execution
if ARGV[0] == 'report'
  generate_client_report
else
  simulate_demo_trading
  puts "\n📄 Generate a client report with: ruby script/simulate_trading_demo.rb report"
end 