#!/usr/bin/env ruby
# Script to generate detailed trading logs for client verification

puts "📋 EMA Trading Bot - Trading Log Generator"
puts "=" * 60

# Load Rails environment
require_relative '../config/environment'

def generate_trading_logs
  puts "\n🕐 Generating Trading Activity Logs..."
  puts "Timestamp: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  
  # Verify paper trading mode
  unless PaperTradingService.paper_trading_enabled?
    puts "❌ Error: Not in paper trading mode!"
    return
  end
  
  puts "✅ Paper Trading Mode: ACTIVE"
  puts "📊 Environment: #{ENV.fetch('RAILS_ENV', 'development')}"
  puts "🔗 Endpoint: https://paper-api.alpaca.markets"
  
  # Create log file with timestamp
  timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
  log_filename = "trading_log_#{timestamp}.txt"
  
  log_content = []
  log_content << "EMA TRADING BOT - DETAILED TRADING LOG"
  log_content << "=" * 50
  log_content << "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << "Mode: Paper Trading (Simulation)"
  log_content << "Endpoint: https://paper-api.alpaca.markets"
  log_content << ""
  
  # Get paper trading service
  paper_service = PaperTradingService.new
  
  # 1. Current Account Status
  log_content << "ACCOUNT STATUS:"
  log_content << "-" * 20
  account_info = paper_service.get_paper_account_info
  if account_info
    log_content << "Account ID: #{account_info[:account_id] || 'N/A'}"
    log_content << "Portfolio Value: $#{account_info[:portfolio_value] || 'N/A'}"
    log_content << "Cash Balance: $#{account_info[:cash_balance] || 'N/A'}"
    log_content << "Buying Power: $#{account_info[:buying_power] || 'N/A'}"
    log_content << "Day Trade Count: #{account_info[:day_trade_count] || 0}"
  else
    log_content << "Account info unavailable"
  end
  log_content << ""
  
  # 2. Current Positions
  log_content << "CURRENT POSITIONS:"
  log_content << "-" * 20
  positions = paper_service.get_paper_positions
  if positions && positions.any?
    positions.each do |position|
      log_content << "#{position[:symbol]}: #{position[:qty]} shares @ $#{position[:avg_cost]} (P/L: $#{position[:unrealized_pl]})"
    end
  else
    log_content << "No current positions"
  end
  log_content << ""
  
  # 3. Recent Market Data Analysis
  log_content << "MARKET DATA ANALYSIS:"
  log_content << "-" * 20
  
  symbols = ['TSLA', 'AAPL', 'NVDA']
  symbols.each do |symbol|
    begin
      log_content << "\n#{symbol} Analysis at #{Time.current.strftime('%H:%M:%S')}:"
      
      # Get current price
      data_service = AlpacaDataService.new
      price_info = data_service.get_current_price(symbol)
      
      if price_info
        log_content << "  Current Price: $#{price_info[:price]}"
        log_content << "  Data Source: #{price_info[:source]}"
        
        # Get EMA data if available
        recent_emas = EmaReading.for_symbol(symbol)
                               .where('timestamp >= ?', 1.hour.ago)
                               .where(period: [5, 8, 22])
                               .order(:timestamp, :period)
                               .last(6)
        
        if recent_emas.any?
          ema5 = recent_emas.select { |r| r.period == 5 }.last
          ema8 = recent_emas.select { |r| r.period == 8 }.last
          ema22 = recent_emas.select { |r| r.period == 22 }.last
          
          if ema5 && ema8
            log_content << "  EMA-5: #{ema5.value.round(2)} (#{ema5.timestamp.strftime('%H:%M:%S')})"
            log_content << "  EMA-8: #{ema8.value.round(2)} (#{ema8.timestamp.strftime('%H:%M:%S')})"
            log_content << "  EMA-22: #{ema22&.value&.round(2) || 'N/A'}"
            
            # Signal analysis
            if ema5.value > ema8.value
              signal_strength = ((ema5.value - ema8.value) / ema8.value * 100).round(2)
              log_content << "  SIGNAL: BULLISH (EMA-5 > EMA-8 by #{signal_strength}%)"
            else
              signal_strength = ((ema8.value - ema5.value) / ema8.value * 100).round(2)
              log_content << "  SIGNAL: BEARISH (EMA-8 > EMA-5 by #{signal_strength}%)"
            end
          end
        else
          log_content << "  EMA Data: Not available (bot not running recently)"
        end
      else
        log_content << "  Market data unavailable (market may be closed)"
      end
      
    rescue => e
      log_content << "  Error analyzing #{symbol}: #{e.message}"
    end
  end
  
  # 4. Recent Trading Signals
  log_content << "\n\nRECENT TRADING SIGNALS:"
  log_content << "-" * 25
  recent_signals = TradingSignal.where('created_at >= ?', 24.hours.ago)
                               .order(created_at: :desc)
                               .limit(10)
  
  if recent_signals.any?
    recent_signals.each do |signal|
      log_content << "#{signal.created_at.strftime('%Y-%m-%d %H:%M:%S')} - #{signal.symbol} #{signal.signal_type.upcase} @ $#{signal.price}"
      log_content << "  EMAs: 5=#{signal.ema5.round(2)}, 8=#{signal.ema8.round(2)}, 22=#{signal.ema22.round(2)}"
    end
  else
    log_content << "No trading signals in last 24 hours"
  end
  
  # 5. Recent Orders
  log_content << "\n\nRECENT ORDERS:"
  log_content << "-" * 15
  recent_orders = paper_service.get_paper_orders(limit: 20)
  if recent_orders && recent_orders.any?
    recent_orders.each do |order|
      log_content << "#{order[:created_at]} - #{order[:symbol]} #{order[:side].upcase} #{order[:qty]} shares @ $#{order[:limit_price] || 'MARKET'} [#{order[:status]}]"
    end
  else
    log_content << "No recent orders found"
  end
  
  # 6. Performance Summary
  log_content << "\n\nPERFORMANCE SUMMARY:"
  log_content << "-" * 20
  performance = paper_service.calculate_paper_performance
  if performance
    log_content << "Total Trades: #{performance[:total_trades] || 0}"
    log_content << "Winning Trades: #{performance[:winning_trades] || 0}"
    log_content << "Losing Trades: #{performance[:losing_trades] || 0}"
    log_content << "Win Rate: #{performance[:win_rate] || 0}%"
    log_content << "Total Return: $#{performance[:total_return_dollar] || 0}"
    log_content << "Return Percentage: #{performance[:total_return_percent] || 0}%"
  end
  
  # 7. System Information
  log_content << "\n\nSYSTEM INFORMATION:"
  log_content << "-" * 20
  log_content << "Bot Status: #{BotState.where(running: true).any? ? 'RUNNING' : 'STOPPED'}"
  log_content << "Tracked Symbols: #{User.first&.configured_symbols&.join(', ') || 'None'}"
  log_content << "Rails Environment: #{Rails.env}"
  log_content << "Alpaca Endpoint: #{ENV.fetch('PAPER_TRADING', 'true') == 'true' ? 'paper-api.alpaca.markets' : 'api.alpaca.markets'}"
  
  # 8. Client Verification Section
  log_content << "\n\nFOR CLIENT VERIFICATION:"
  log_content << "-" * 25
  log_content << "This log contains real market data and timestamps that can be verified against live market feeds."
  log_content << "All trades shown are simulated (paper trading) but use real market prices and timing."
  log_content << "You can compare the timestamps and prices against your live trading platform."
  log_content << ""
  log_content << "Key verification points:"
  log_content << "1. Timestamps are in #{Time.current.strftime('%Z')} timezone"
  log_content << "2. Market data prices should match live feeds within normal spread ranges"
  log_content << "3. EMA calculations can be verified using standard EMA formulas"
  log_content << "4. Signal timing shows when crossovers were detected"
  log_content << ""
  log_content << "Log generated at: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  
  # Write to file
  File.write(log_filename, log_content.join("\n"))
  
  # Display summary
  puts "\n📋 Trading Log Generated:"
  puts "📁 File: #{log_filename}"
  puts "📊 Contains:"
  puts "   • Account status and positions"
  puts "   • Real-time market data analysis"
  puts "   • EMA calculations and signals"
  puts "   • Recent trading activity"
  puts "   • Performance metrics"
  puts "   • Verification timestamps"
  
  # Display recent content for immediate review
  puts "\n📖 Recent Activity Summary:"
  puts "-" * 30
  puts log_content.last(20).join("\n")
  
  puts "\n💾 Full log saved to: #{log_filename}"
  puts "📧 Send this file to your client for verification!"
  
  return log_filename
end

def simulate_market_activity
  puts "\n🚀 Simulating Market Activity..."
  
  symbols = ['TSLA', 'AAPL']
  
  symbols.each do |symbol|
    puts "\n📊 Processing #{symbol}..."
    
    begin
      # Run market ping to generate activity
      MarketPingJob.perform_now(symbol)
      puts "✅ Market data processed for #{symbol}"
      
      # Small delay between symbols
      sleep(2)
      
    rescue => e
      puts "⚠️  Error processing #{symbol}: #{e.message}"
    end
  end
  
  puts "\n✅ Market activity simulation complete!"
end

# Main execution
if ARGV[0] == 'simulate'
  simulate_market_activity
  puts "\n📋 Generate logs with: ruby script/generate_trading_logs.rb"
elsif ARGV[0] == 'both'
  simulate_market_activity
  sleep(3)
  generate_trading_logs
else
  log_file = generate_trading_logs
  puts "\n🎯 Next steps:"
  puts "1. Review the log file: #{log_file}"
  puts "2. Send it to your client for verification"
  puts "3. Run 'ruby script/generate_trading_logs.rb simulate' to generate more activity"
  puts "4. Run 'ruby script/generate_trading_logs.rb both' to simulate and log in one command"
end 