#!/usr/bin/env ruby
# Simple logs for client verification with timezone data

puts "📊 EMA Trading Bot - Client Verification Logs"
puts "=" * 50

require_relative '../config/environment'

def generate_simple_logs
  timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
  log_filename = "client_verification_#{timestamp}.txt"
  
  current_time = Time.current
  est_time = current_time.in_time_zone('America/New_York')
  pst_time = current_time.in_time_zone('America/Los_Angeles')
  
  log_content = []
  log_content << "EMA TRADING BOT - CLIENT VERIFICATION LOGS"
  log_content << "=" * 45
  log_content << ""
  log_content << "PAPER TRADING MODE (Simulation Only - No Real Money)"
  log_content << ""
  log_content << "TIMESTAMP REFERENCE:"
  log_content << "------------------"
  log_content << "UTC Time:  #{current_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << "EST Time:  #{est_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << "PST Time:  #{pst_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << ""
  
  # Check if market is open
  market_status = check_market_status(est_time)
  log_content << "MARKET STATUS: #{market_status}"
  log_content << ""
  
  # Paper trading account info
  begin
    paper_service = PaperTradingService.new
    account_info = paper_service.get_paper_account_info
    
    if account_info && account_info[:portfolio_value]
      log_content << "PAPER TRADING ACCOUNT:"
      log_content << "---------------------"
      log_content << "Portfolio Value: $#{account_info[:portfolio_value]&.round(2) || 'N/A'}"
      log_content << "Cash Balance: $#{account_info[:cash_balance]&.round(2) || 'N/A'}"
      log_content << "Account Status: #{account_info[:account_status] || 'Unknown'}"
      log_content << ""
    else
      log_content << "PAPER TRADING ACCOUNT: Unable to retrieve (market may be closed)"
      log_content << ""
    end
  rescue => e
    log_content << "PAPER TRADING ACCOUNT: Error retrieving data"
    log_content << ""
  end
  
  # Recent EMA data for verification
  symbols = ['TSLA', 'AAPL', 'NVDA']
  
  log_content << "RECENT EMA DATA FOR CLIENT VERIFICATION:"
  log_content << "========================================="
  log_content << ""
  
  symbols.each do |symbol|
    log_content << "#{symbol} DATA:"
    log_content << "-" * 12
    
    # Get recent EMA readings from database
    recent_emas = EmaReading.for_symbol(symbol)
                           .where('timestamp >= ?', 2.hours.ago)
                           .where(period: [5, 8, 22])
                           .order(:timestamp, :period)
                           .last(9) # 3 readings * 3 periods
    
    if recent_emas.any?
      # Group by timestamp
      ema_groups = recent_emas.group_by(&:timestamp)
      
      ema_groups.each do |timestamp, readings|
        utc_time = timestamp
        est_time = timestamp.in_time_zone('America/New_York')
        pst_time = timestamp.in_time_zone('America/Los_Angeles')
        
        log_content << ""
        log_content << "Timestamp:"
        log_content << "  UTC: #{utc_time.strftime('%Y-%m-%d %H:%M:%S')}"
        log_content << "  EST: #{est_time.strftime('%Y-%m-%d %H:%M:%S')}"
        log_content << "  PST: #{pst_time.strftime('%Y-%m-%d %H:%M:%S')}"
        
        ema5 = readings.find { |r| r.period == 5 }
        ema8 = readings.find { |r| r.period == 8 }
        ema22 = readings.find { |r| r.period == 22 }
        
        if ema5 && ema8 && ema5.value && ema8.value
          log_content << "EMA Values:"
          log_content << "  EMA-5:  $#{ema5.value.round(2)}"
          log_content << "  EMA-8:  $#{ema8.value.round(2)}"
          log_content << "  EMA-22: $#{ema22&.value&.round(2) || 'N/A'}"
          
          # Signal analysis
          if ema5.value > ema8.value
            difference = ((ema5.value - ema8.value) / ema8.value * 100).round(3)
            log_content << "Signal: BULLISH (EMA-5 is #{difference}% above EMA-8)"
          else
            difference = ((ema8.value - ema5.value) / ema8.value * 100).round(3)
            log_content << "Signal: BEARISH (EMA-8 is #{difference}% above EMA-5)"
          end
        end
      end
    else
      log_content << ""
      log_content << "No recent EMA data (market may be closed)"
      log_content << "Note: During market hours (9:30 AM - 4:00 PM EST),"
      log_content << "      real EMA calculations would appear here"
    end
    
    log_content << ""
  end
  
  # Recent trading signals
  begin
    recent_signals = TradingSignal.where('created_at >= ?', 24.hours.ago)
                                  .order(created_at: :desc)
                                  .limit(5)
    
    if recent_signals.any?
      log_content << "RECENT TRADING SIGNALS:"
      log_content << "======================="
      log_content << ""
      
      recent_signals.each do |signal|
        utc_time = signal.created_at
        est_time = utc_time.in_time_zone('America/New_York')
        pst_time = utc_time.in_time_zone('America/Los_Angeles')
        
        log_content << "#{signal.symbol} #{signal.signal_type.upcase} SIGNAL"
        log_content << "UTC: #{utc_time.strftime('%Y-%m-%d %H:%M:%S')}"
        log_content << "EST: #{est_time.strftime('%Y-%m-%d %H:%M:%S')}"
        log_content << "PST: #{pst_time.strftime('%Y-%m-%d %H:%M:%S')}"
        log_content << "Price: $#{signal.price}"
        log_content << "EMA-5: $#{signal.ema5&.round(2)}"
        log_content << "EMA-8: $#{signal.ema8&.round(2)}"
        log_content << "EMA-22: $#{signal.ema22&.round(2)}"
        log_content << ""
      end
    else
      log_content << "RECENT SIGNALS: None in last 24 hours"
      log_content << ""
    end
  rescue => e
    log_content << "RECENT SIGNALS: Error retrieving data"
    log_content << ""
  end
  
  # Current positions
  begin
    positions = paper_service.get_paper_positions
    if positions && positions.any?
      log_content << "CURRENT PAPER POSITIONS:"
      log_content << "========================"
      log_content << ""
      
      positions.each do |position|
        log_content << "#{position[:symbol]}: #{position[:qty]} shares"
        log_content << "  Average Cost: $#{position[:avg_cost]}"
        log_content << "  Current P/L: $#{position[:unrealized_pl]}"
        log_content << "  Market Value: $#{position[:market_value]}"
        log_content << ""
      end
    else
      log_content << "CURRENT POSITIONS: None"
      log_content << ""
    end
  rescue => e
    log_content << "CURRENT POSITIONS: Error retrieving data"
    log_content << ""
  end
  
  # How to verify section
  log_content << "HOW TO VERIFY THIS DATA:"
  log_content << "========================"
  log_content << ""
  log_content << "1. TIMESTAMP VERIFICATION:"
  log_content << "   • Convert times to your timezone"
  log_content << "   • Check if times match market activity"
  log_content << ""
  log_content << "2. PRICE VERIFICATION:"
  log_content << "   • Open your trading platform (TradingView, TD Ameritrade, etc.)"
  log_content << "   • Navigate to the exact timestamp shown above"
  log_content << "   • Check if prices match within normal bid/ask spread"
  log_content << ""
  log_content << "3. EMA VERIFICATION:"
  log_content << "   • Add EMA indicators: 5-period, 8-period, 22-period"
  log_content << "   • Use 5-minute timeframe"
  log_content << "   • Compare values - they should be identical"
  log_content << ""
  log_content << "4. SIGNAL VERIFICATION:"
  log_content << "   • Check if EMA-5 actually crossed above/below EMA-8"
  log_content << "   • Verify timing matches our signal timestamps"
  log_content << ""
  log_content << "CONFIDENCE FACTORS:"
  log_content << "• Same data source as Wall Street (Alpaca)"
  log_content << "• Standard EMA mathematical formulas"
  log_content << "• Real-time market synchronization"
  log_content << "• No real money at risk (paper trading)"
  log_content << ""
  log_content << "Questions? We can provide:"
  log_content << "• Live screen sharing during market hours"
  log_content << "• Additional verification logs"
  log_content << "• Side-by-side comparison with your platform"
  log_content << ""
  log_content << "Generated: #{current_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  
  # Write to file
  File.write(log_filename, log_content.join("\n"))
  
  return log_filename, log_content
end

def check_market_status(est_time)
  current_wday = est_time.wday
  
  # Weekend check
  if current_wday == 0 || current_wday == 6
    return "CLOSED (Weekend)"
  end
  
  # Market hours check (9:30 AM to 4:00 PM ET)
  market_open = est_time.change(hour: 9, min: 30)
  market_close = est_time.change(hour: 16, min: 0)
  
  if est_time < market_open
    return "CLOSED (Before 9:30 AM EST)"
  elsif est_time > market_close
    return "CLOSED (After 4:00 PM EST)"
  else
    return "OPEN (9:30 AM - 4:00 PM EST)"
  end
end

# Generate logs
puts "\n🔍 Generating simple verification logs for your client..."

begin
  log_file, log_content = generate_simple_logs
  
  puts "\n✅ Client Verification Logs Created!"
  puts "📁 File: #{log_file}"
  puts "\n📋 Log Contents Preview:"
  puts "-" * 30
  puts log_content.first(20).join("\n")
  puts "\n... (full log saved to file)"
  
  puts "\n💡 What this shows your client:"
  puts "• Real timestamps in UTC, EST, and PST"
  puts "• Actual EMA calculations from market data"
  puts "• Trading signals with exact timing"
  puts "• Current paper trading positions"
  puts "• Step-by-step verification instructions"
  
  puts "\n📧 Send #{log_file} to your client"
  puts "🎯 They can verify everything on their trading platform"
  puts "\n⚠️  Remember: This is PAPER TRADING (simulation only)"
  
rescue => e
  puts "\n❌ Error generating logs: #{e.message}"
  puts "💡 Make sure the Rails environment is loaded properly"
end 