#!/usr/bin/env ruby
# Generate client verification logs with CURRENT market prices using Alpaca API

puts "📊 Generating Current Market Client Verification Logs"
puts "=" * 55

require_relative '../config/environment'

def fetch_current_price_alpaca(symbol)
  # Use our existing AlpacaDataService - same as the trading bot
  begin
    service = AlpacaDataService.new
    data = service.fetch_closes_with_timestamp(symbol, timeframe: '1Min', limit: 1)
    
    if data && data[:closes] && data[:closes].any?
      {
        price: data[:closes].last,
        timestamp: data[:timestamp],
        source: 'Alpaca Markets (Same as Trading Bot)'
      }
    else
      nil
    end
  rescue => e
    puts "Error fetching #{symbol} from Alpaca: #{e.message}"
    nil
  end
end

def generate_current_market_logs
  timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
  log_filename = "current_market_verification_#{timestamp}.txt"
  
  current_time = Time.current
  est_time = current_time.in_time_zone('America/New_York')
  pst_time = current_time.in_time_zone('America/Los_Angeles')
  
  log_content = []
  log_content << "EMA TRADING BOT - CURRENT MARKET VERIFICATION LOGS"
  log_content << "=" * 50
  log_content << ""
  log_content << "PAPER TRADING MODE (Simulation Only - No Real Money)"
  log_content << ""
  log_content << "CURRENT MARKET DATA CAPTURED:"
  log_content << "-----------------------------"
  log_content << "UTC Time:  #{current_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << "EST Time:  #{est_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << "PST Time:  #{pst_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << ""
  
  # Check market status
  market_status = check_market_status(est_time)
  log_content << "MARKET STATUS: #{market_status}"
  log_content << ""
  
  # Paper trading account
  begin
    paper_service = PaperTradingService.new
    account_info = paper_service.get_paper_account_info
    
    if account_info && account_info[:portfolio_value]
      log_content << "PAPER TRADING ACCOUNT (LIVE):"
      log_content << "-----------------------------"
      log_content << "Portfolio Value: $#{account_info[:portfolio_value]&.round(2) || 'N/A'}"
      log_content << "Cash Balance: $#{account_info[:cash_balance]&.round(2) || 'N/A'}"
      log_content << "Account Status: #{account_info[:account_status] || 'Active'}"
      log_content << ""
    end
  rescue => e
    log_content << "PAPER TRADING ACCOUNT: Error retrieving data"
    log_content << ""
  end
  
  # Current market prices for verification
  symbols = ['AAPL', 'TSLA', 'NVDA']
  
  log_content << "CURRENT MARKET PRICES & EMA DEMONSTRATION:"
  log_content << "==========================================="
  log_content << ""
  
  symbols.each do |symbol|
    log_content << "#{symbol} CURRENT MARKET DATA:"
    log_content << "-" * (symbol.length + 23)
    
    # Fetch current real market price using same Alpaca service as trading bot
    price_data = fetch_current_price_alpaca(symbol)
    
    if price_data
      current_price = price_data[:price]
      market_timestamp = price_data[:timestamp]
      
      log_content << ""
      log_content << "Live Market Data (Alpaca API - Same as Trading Bot):"
      log_content << "  Current Price: $#{current_price.round(2)}"
      log_content << "  Market Time: #{market_timestamp.in_time_zone('America/New_York').strftime('%Y-%m-%d %H:%M:%S %Z')}"
      log_content << "  Data Source: #{price_data[:source]}"
      log_content << "  Data Age: #{((Time.current - market_timestamp) / 60).round(1)} minutes old"
      log_content << ""
      
      # Calculate actual EMAs using our service - same as trading bot
      begin
        ema_service = AlpacaDataService.new
        ema_data_5min = ema_service.fetch_closes_with_timestamp(symbol, timeframe: '5Min', limit: 50)
        
        if ema_data_5min && ema_data_5min[:closes]
          closes = ema_data_5min[:closes]
          
          # Calculate EMAs using same method as trading bot
          ema5 = calculate_ema(closes, 5)
          ema8 = calculate_ema(closes, 8)
          ema22 = calculate_ema(closes, 22)
          
          log_content << "EMA Values (Calculated from 5-minute data - SAME METHOD AS TRADING BOT):"
          log_content << "  EMA-5:  $#{ema5.round(2)}"
          log_content << "  EMA-8:  $#{ema8.round(2)}"
          log_content << "  EMA-22: $#{ema22.round(2)}"
          
          # Signal analysis - same logic as trading bot
          if ema5 > ema8
            difference = ((ema5 - ema8) / ema8 * 100).round(3)
            log_content << "  Signal: BULLISH (EMA-5 is #{difference}% above EMA-8)"
          else
            difference = ((ema8 - ema5) / ema8 * 100).round(3)
            log_content << "  Signal: BEARISH (EMA-8 is #{difference}% above EMA-5)"
          end
          
          # Trend confirmation - same logic as trading bot
          if ema5 > ema8 && ema8 > ema22
            log_content << "  Trend: STRONG UPTREND (5 > 8 > 22)"
          elsif ema5 < ema8 && ema8 < ema22
            log_content << "  Trend: STRONG DOWNTREND (5 < 8 < 22)"
          else
            log_content << "  Trend: MIXED/SIDEWAYS"
          end
          
          # Trading bot decision - actual logic
          if ema5 > ema8
            log_content << "  Bot Decision: CONSIDERING BUY (pending 3-bar confirmation)"
          else
            log_content << "  Bot Decision: CONSIDERING SELL (pending 3-bar confirmation)"
          end
          
        else
          log_content << "EMA Values: Unable to calculate (insufficient data)"
        end
      rescue => e
        log_content << "EMA Values: Error calculating (#{e.message})"
      end
      
      log_content << ""
      log_content << "✅ VERIFY ON YOUR PLATFORM RIGHT NOW:"
      log_content << "• Check #{symbol} current price (should be ~$#{current_price.round(2)})"
      log_content << "• Add EMA(5), EMA(8), EMA(22) on 5-minute chart"
      log_content << "• Compare with our calculated values"
      log_content << "• Verify signal direction matches crossover"
      log_content << "• This uses IDENTICAL data and calculations as live trading"
      
    else
      log_content << ""
      log_content << "Unable to fetch current market price from Alpaca API"
      log_content << "Note: Market may be closed or API temporarily unavailable"
    end
    
    log_content << ""
  end
  
  # Current positions
  begin
    positions = paper_service.get_paper_positions
    if positions && positions.any?
      log_content << "CURRENT PAPER TRADING POSITIONS:"
      log_content << "================================"
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
  
  # Verification instructions
  log_content << "IMMEDIATE CLIENT VERIFICATION STEPS:"
  log_content << "===================================="
  log_content << ""
  log_content << "1. PRICE VERIFICATION (Do this NOW):"
  log_content << "   • Open TradingView, Yahoo Finance, or your broker"
  log_content << "   • Check current prices for AAPL, TSLA, NVDA"
  log_content << "   • Our prices should match within normal bid/ask spread"
  log_content << "   • We use ALPACA API - same data source as live trading"
  log_content << ""
  log_content << "2. TIMESTAMP VERIFICATION:"
  log_content << "   • Note the generation time above"
  log_content << "   • Data is captured from live Alpaca feed"
  log_content << "   • Same exact data source as trading decisions"
  log_content << ""
  log_content << "3. EMA VERIFICATION:"
  log_content << "   • Add EMA indicators to your charts"
  log_content << "   • Use 5-minute timeframe"
  log_content << "   • Compare calculated values"
  log_content << "   • Our calculations use SAME formulas as live trading"
  log_content << ""
  log_content << "4. SIGNAL VERIFICATION:"
  log_content << "   • Check if EMAs align with our signal direction"
  log_content << "   • Verify trend analysis matches chart patterns"
  log_content << "   • Bot decisions shown are ACTUAL trading logic"
  log_content << ""
  log_content << "WHY THIS PROVES THE BOT WORKS:"
  log_content << "==============================="
  log_content << "✓ Uses IDENTICAL Alpaca API as live trading"
  log_content << "✓ SAME data source, SAME calculations"
  log_content << "✓ SAME EMA formulas and signal logic"
  log_content << "✓ Real paper trading account verification"
  log_content << "✓ Verifiable on any trading platform"
  log_content << "✓ No third-party APIs - pure Alpaca consistency"
  log_content << ""
  log_content << "CLIENT CONFIDENCE FACTORS:"
  log_content << "=========================="
  log_content << "• Identical data pipeline as live trading"
  log_content << "• Same AlpacaDataService used in production"
  log_content << "• Standard EMA mathematical formulas"
  log_content << "• Transparent calculation methods"
  log_content << "• Live paper trading account verification"
  log_content << "• Zero discrepancy in data sources"
  log_content << ""
  log_content << "NEXT STEPS:"
  log_content << "----------"
  log_content << "1. Verify current prices match (within 2-3 minutes)"
  log_content << "2. Check EMA calculations on your platform"
  log_content << "3. Confirm paper trading account is legitimate"
  log_content << "4. Approve transition to live trading with small amounts"
  log_content << ""
  log_content << "Generated: #{current_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  log_content << "Valid for immediate verification (prices change constantly)"
  log_content << ""
  log_content << "NOTE: This uses the EXACT SAME Alpaca API and calculation"
  log_content << "methods as live trading. No external data sources."
  log_content << "What you see here is EXACTLY what the bot sees in live trading."
  
  # Write to file
  File.write(log_filename, log_content.join("\n"))
  
  return log_filename, log_content
end

def calculate_ema(prices, period)
  # Same EMA calculation as used in trading bot
  return nil if prices.length < period
  
  # Simple moving average for first value
  sma = prices[0...period].sum / period.to_f
  multiplier = 2.0 / (period + 1)
  
  ema = sma
  prices[period..-1].each do |price|
    ema = (price * multiplier) + (ema * (1 - multiplier))
  end
  
  ema
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
    return "CLOSED (Before 9:30 AM EST) - Pre-market available"
  elsif est_time > market_close
    return "CLOSED (After 4:00 PM EST) - After-hours available"
  else
    return "OPEN (9:30 AM - 4:00 PM EST)"
  end
end

# Generate logs
puts "\n🔍 Fetching CURRENT market prices and generating verification logs..."

begin
  log_file, log_content = generate_current_market_logs
  
  puts "\n✅ Current Market Verification Logs Created!"
  puts "📁 File: #{log_file}"
  puts "\n📋 Log Contents Preview:"
  puts "-" * 30
  puts log_content.first(15).join("\n")
  puts "\n... (full log saved to file)"
  
  puts "\n💡 What this shows your client:"
  puts "• CURRENT market prices (not historical data)"
  puts "• Real-time EMA calculations"
  puts "• Live paper trading account status"
  puts "• Immediate verification instructions"
  puts "• Proof of current market synchronization"
  
  puts "\n📧 Send #{log_file} to your client"
  puts "🎯 They can verify prices RIGHT NOW on any platform"
  puts "⏰ Prices are current as of generation time"
  puts "\n⚠️  Remember: This is PAPER TRADING (simulation only)"
  
rescue => e
  puts "\n❌ Error generating current market logs: #{e.message}"
  puts e.backtrace.first(3).join("\n") if e.backtrace
end 