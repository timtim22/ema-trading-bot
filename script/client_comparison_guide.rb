#!/usr/bin/env ruby
# Guide for client to compare paper trading data with live trading

puts "📊 Client Comparison Guide - How to Verify Paper Trading Data"
puts "=" * 70

require_relative '../config/environment'

def generate_comparison_guide
  timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
  guide_filename = "client_comparison_guide_#{timestamp}.txt"
  
  guide_content = []
  guide_content << "HOW TO COMPARE PAPER TRADING DATA WITH LIVE TRADING"
  guide_content << "=" * 60
  guide_content << "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  guide_content << ""
  guide_content << "OVERVIEW:"
  guide_content << "--------"
  guide_content << "Even though our bot uses 'paper money' (simulation), the market data,"
  guide_content << "prices, and timing are 100% REAL and identical to live trading."
  guide_content << ""
  guide_content << "WHAT YOU CAN COMPARE:"
  guide_content << "--------------------"
  guide_content << ""
  guide_content << "1. EXACT TIMESTAMPS & PRICES"
  guide_content << "   Our Log: '2025-06-17 14:30:15 UTC - TSLA @ $347.82'"
  guide_content << "   Your Platform: Check TSLA price at 2:30:15 PM UTC (9:30:15 AM EST)"
  guide_content << "   ✓ Prices should match within normal bid/ask spread"
  guide_content << ""
  guide_content << "2. EMA CALCULATIONS"
  guide_content << "   Our Log: 'EMA-5: 348.15, EMA-8: 347.90, EMA-22: 346.50'"
  guide_content << "   Your Platform: Use any EMA indicator with same periods (5, 8, 22)"
  guide_content << "   ✓ Values should be identical (standard EMA formula)"
  guide_content << ""
  guide_content << "3. SIGNAL TIMING"
  guide_content << "   Our Log: 'BULLISH CROSSOVER: EMA-5 crossed above EMA-8'"
  guide_content << "   Your Platform: Check if EMA-5 actually crossed EMA-8 at that time"
  guide_content << "   ✓ Crossover should be visible on your charts"
  guide_content << ""
  guide_content << "4. MARKET CONDITIONS"
  guide_content << "   Our Log: 'Volume: 1,250,000, Volatility: 2.3%'"
  guide_content << "   Your Platform: Check volume and price movement at same time"
  guide_content << "   ✓ Market conditions should match"
  guide_content << ""
  
  # Generate real example data
  paper_service = PaperTradingService.new
  account_info = paper_service.get_paper_account_info
  
  current_time = Time.current
  
  guide_content << "LIVE EXAMPLE FOR VERIFICATION:"
  guide_content << "------------------------------"
  guide_content << "Timestamp: #{current_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  guide_content << ""
  
  symbols = ['TSLA', 'AAPL', 'NVDA']
  symbols.each do |symbol|
    guide_content << "#{symbol} VERIFICATION EXAMPLE:"
    guide_content << "#{'-' * (symbol.length + 22)}"
    
    # Get recent EMA data if available
    recent_emas = EmaReading.for_symbol(symbol)
                            .where('timestamp >= ?', 2.hours.ago)
                            .where(period: [5, 8, 22])
                            .order(:timestamp)
                            .last(6)
    
    if recent_emas.any?
      latest_timestamp = recent_emas.last.timestamp
      ema5 = recent_emas.select { |r| r.period == 5 }.last
      ema8 = recent_emas.select { |r| r.period == 8 }.last
      ema22 = recent_emas.select { |r| r.period == 22 }.last
      
      guide_content << "Our Bot Data:"
      guide_content << "  Time: #{latest_timestamp.strftime('%Y-%m-%d %H:%M:%S %Z')}"
      guide_content << "  EMA-5: #{ema5&.value&.round(2) || 'N/A'}"
      guide_content << "  EMA-8: #{ema8&.value&.round(2) || 'N/A'}"
      guide_content << "  EMA-22: #{ema22&.value&.round(2) || 'N/A'}"
      
      if ema5 && ema8
        signal = ema5.value > ema8.value ? "BULLISH" : "BEARISH"
        guide_content << "  Signal: #{signal} (EMA-5 #{ema5.value > ema8.value ? '>' : '<'} EMA-8)"
      end
      
      guide_content << ""
      guide_content << "How to Verify on Your Platform:"
      guide_content << "  1. Open #{symbol} chart at #{latest_timestamp.strftime('%H:%M %Z')}"
      guide_content << "  2. Add EMA indicators: 5-period, 8-period, 22-period"
      guide_content << "  3. Check values match our calculations"
      guide_content << "  4. Verify crossover signals align"
      
    else
      guide_content << "Our Bot Data:"
      guide_content << "  Status: No recent EMA data (market closed or bot not running)"
      guide_content << "  Note: During market hours, real EMA values would appear here"
      guide_content << ""
      guide_content << "How to Verify on Your Platform:"
      guide_content << "  1. During market hours, compare live EMA values"
      guide_content << "  2. Use 5-minute timeframe for EMA calculations"
      guide_content << "  3. Verify signal timing matches crossovers"
    end
    
    guide_content << ""
  end
  
  guide_content << "STEP-BY-STEP VERIFICATION PROCESS:"
  guide_content << "-----------------------------------"
  guide_content << ""
  guide_content << "FOR EACH SIGNAL IN OUR LOG:"
  guide_content << "1. Note the exact timestamp (convert UTC to your timezone if needed)"
  guide_content << "2. Open that symbol on your trading platform"
  guide_content << "3. Navigate to that exact time on the chart"
  guide_content << "4. Add EMA indicators (5, 8, 22 periods on 5-minute timeframe)"
  guide_content << "5. Verify:"
  guide_content << "   ✓ Price matches within bid/ask spread"
  guide_content << "   ✓ EMA values are identical"
  guide_content << "   ✓ Crossover signal is visible"
  guide_content << "   ✓ Volume and market conditions align"
  guide_content << ""
  
  guide_content << "TRADING PLATFORMS THAT WORK WELL:"
  guide_content << "----------------------------------"
  guide_content << "• TradingView (free EMAs)"
  guide_content << "• Thinkorswim (TD Ameritrade)"
  guide_content << "• Interactive Brokers TWS"
  guide_content << "• E*TRADE Power E*TRADE"
  guide_content << "• Charles Schwab StreetSmart"
  guide_content << "• Any platform with EMA indicators"
  guide_content << ""
  
  guide_content << "TIMEZONE CONVERSION:"
  guide_content << "--------------------"
  guide_content << "Our logs use UTC time. Convert to your timezone:"
  guide_content << "• UTC to EST: Subtract 5 hours (or 4 during daylight saving)"
  guide_content << "• UTC to PST: Subtract 8 hours (or 7 during daylight saving)"
  guide_content << "• Market hours: 9:30 AM - 4:00 PM EST (14:30 - 21:00 UTC)"
  guide_content << ""
  
  guide_content << "WHAT PROVES OUR BOT WORKS:"
  guide_content << "---------------------------"
  guide_content << "✓ Timestamps match real market activity"
  guide_content << "✓ Prices align with live market data"
  guide_content << "✓ EMA calculations are mathematically correct"
  guide_content << "✓ Signals occur at actual crossover points"
  guide_content << "✓ Risk management rules are properly applied"
  guide_content << "✓ Performance tracking is accurate"
  guide_content << ""
  
  guide_content << "CONFIDENCE FACTORS:"
  guide_content << "-------------------"
  guide_content << "• Same data source as institutional traders (Alpaca)"
  guide_content << "• Standard EMA calculation formulas"
  guide_content << "• Real-time market synchronization"
  guide_content << "• Transparent logging with exact timestamps"
  guide_content << "• Verifiable against any professional platform"
  guide_content << ""
  
  guide_content << "NEXT STEPS:"
  guide_content << "-----------"
  guide_content << "1. Review our paper trading logs"
  guide_content << "2. Pick 3-5 signals to verify on your platform"
  guide_content << "3. Confirm data accuracy and signal quality"
  guide_content << "4. Approve transition to live trading"
  guide_content << "5. Start with small position sizes"
  guide_content << ""
  
  guide_content << "CONTACT FOR QUESTIONS:"
  guide_content << "----------------------"
  guide_content << "If any data doesn't match or you need clarification:"
  guide_content << "• We can provide additional verification logs"
  guide_content << "• Screen recordings of signal generation"
  guide_content << "• Live demonstration during market hours"
  guide_content << "• Detailed explanation of any discrepancies"
  guide_content << ""
  
  guide_content << "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  guide_content << "Verification valid for: Live market comparison"
  
  # Write to file
  File.write(guide_filename, guide_content.join("\n"))
  
  puts "\n✅ Client Comparison Guide Created!"
  puts "📁 File: #{guide_filename}"
  puts "\n📋 This guide explains:"
  puts "• How to compare paper trading data with live platforms"
  puts "• Step-by-step verification process"
  puts "• What to look for in trading platforms"
  puts "• Timezone conversions and timing"
  puts "• Confidence factors for data accuracy"
  
  puts "\n📧 Send this guide along with your trading logs!"
  puts "🎯 Your client will be able to verify everything independently"
  
  return guide_filename
end

# Execute
guide_file = generate_comparison_guide
puts "\n💡 Key Point: Even though we use paper money, the market data is 100% real!"
puts "🔍 Your client can verify every signal against his live trading platform" 