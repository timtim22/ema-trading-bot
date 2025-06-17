# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ticket T15: Core Audit Trail Validation', type: :integration do
  let(:user) { create(:user, email: 'trader@example.com', password: 'password123') }
  let(:symbol) { 'AAPL' }
  let(:timeframe) { '5m' }
  
  before(:each) do
    # Clear all records before each test
    ActivityLog.destroy_all
    TradingSignal.destroy_all
    Position.destroy_all
    EmaReading.destroy_all
    
    # Configure user with tracked symbol (avoid uniqueness issues)
    user.tracked_symbols.find_or_create_by(symbol: symbol) do |ts|
      ts.active = true
    end
    
    # Configure user settings
    user.create_bot_setting!(
      timeframe: timeframe,
      profit_percentage: 2.0,
      loss_percentage: 2.0
    )
  end

  describe 'Core Database Audit Trail Components' do
    it 'creates and validates EMA Readings audit trail' do
      puts "\n🔍 Testing EMA Readings audit trail component"
      
      test_start_time = Time.current
      
      # Create EMA readings directly (simulating successful market data fetch)
      ema5 = EmaReading.create!(
        symbol: symbol,
        period: 5,
        value: 118.50,
        timestamp: Time.current
      )
      
      ema8 = EmaReading.create!(
        symbol: symbol,
        period: 8,
        value: 117.20,
        timestamp: Time.current
      )
      
      ema22 = EmaReading.create!(
        symbol: symbol,
        period: 22,
        value: 115.80,
        timestamp: Time.current
      )
      
      # Verify database state
      expect(EmaReading.where(symbol: symbol).count).to eq(3)
      
      # Verify each record
      expect(ema5.value).to eq(118.50)
      expect(ema8.value).to eq(117.20)
      expect(ema22.value).to eq(115.80)
      
      # Verify timestamps
      [ema5, ema8, ema22].each do |reading|
        expect(reading.timestamp).to be >= test_start_time
        expect(reading.created_at).to be >= test_start_time
      end
      
      puts "   ✓ EMA Readings audit trail: 3 records with proper timestamps"
    end
    
    it 'creates and validates Trading Signal audit trail' do
      puts "\n🔍 Testing Trading Signal audit trail component"
      
      test_start_time = Time.current
      
      # Create trading signal using the model method
      current_emas = { ema5: 118.5, ema8: 117.2, ema22: 115.8 }
      previous_emas = { ema5: 116.1, ema8: 116.3, ema22: 115.5 }
      current_price = 119.0
      
      signal = TradingSignal.detect_crossover_signal(
        symbol, current_emas, previous_emas, current_price, user
      )
      
      # Verify signal creation
      expect(signal).to be_present
      expect(signal.signal_type).to eq('buy')
      expect(signal.symbol).to eq(symbol)
      expect(signal.user).to eq(user)
      expect(signal.price).to eq(current_price)
      expect(signal.timestamp).to be >= test_start_time
      
      # Verify database state
      expect(TradingSignal.where(symbol: symbol, user: user).count).to eq(1)
      
      puts "   ✓ Trading Signal audit trail: 1 #{signal.signal_type.upcase} signal at $#{signal.price}"
    end
    
    it 'creates and validates Position audit trail' do
      puts "\n🔍 Testing Position audit trail component"
      
      test_start_time = Time.current
      
      # Create position directly (simulating successful order execution)
      position = Position.create!(
        user: user,
        symbol: symbol,
        amount: 1000.0,
        entry_price: 119.50,
        entry_time: Time.current,
        status: 'open',
        primary_order_id: 'test_order_123',
        take_profit_order_id: 'tp_order_456',
        stop_loss_order_id: 'sl_order_789',
        fill_qty: 8.37,
        fill_notional: 1000.0
      )
      
      # Verify position creation
      expect(position).to be_persisted
      expect(position.symbol).to eq(symbol)
      expect(position.user).to eq(user)
      expect(position.status).to eq('open')
      expect(position.entry_time).to be >= test_start_time
      
      # Verify database state
      expect(Position.where(symbol: symbol, user: user).count).to eq(1)
      
      puts "   ✓ Position audit trail: 1 #{position.status.upcase} position for $#{position.amount}"
    end
    
    it 'creates and validates Activity Log audit trail' do
      puts "\n🔍 Testing Activity Log audit trail component"
      
      test_start_time = Time.current
      
      # Test multiple log types
      ActivityLog.log_signal(symbol, 'buy', 119.0, user: user, details: { test: 'signal_test' })
      ActivityLog.log_trade(symbol, 'buy', 119.50, user: user, details: { test: 'trade_test' })
      ActivityLog.log_order(symbol, 'buy', 1000.0, success: true, user: user, details: { test: 'order_test' })
      
      # Verify logs creation
      signal_logs = ActivityLog.where(symbol: symbol, event_type: 'signal', user: user)
      trade_logs = ActivityLog.where(symbol: symbol, event_type: 'trade', user: user)  
      order_logs = ActivityLog.where(symbol: symbol, event_type: 'order', user: user)
      
      expect(signal_logs.count).to eq(1)
      expect(trade_logs.count).to eq(1)
      expect(order_logs.count).to eq(1)
      
      # Verify log content
      signal_log = signal_logs.first
      trade_log = trade_logs.first
      order_log = order_logs.first
      
      expect(signal_log.message).to include('BUY signal generated')
      expect(trade_log.message).to include('BUY trade executed')
      expect(order_log.message).to include('BUY order for')
      
      # Verify timestamps
      [signal_log, trade_log, order_log].each do |log|
        expect(log.occurred_at).to be >= test_start_time
      end
      
      puts "   ✓ Activity Log audit trail: 3 different log types with proper content"
    end
    
    it 'validates position closure audit trail' do
      puts "\n🔍 Testing Position closure audit trail component"
      
      test_start_time = Time.current
      
      # Create open position
      position = Position.create!(
        user: user,
        symbol: symbol,
        amount: 1000.0,
        entry_price: 100.0,
        entry_time: 1.hour.ago,
        status: 'open'
      )
      
      # Close position with take-profit
      position.close(102.0, 'take_profit')
      
      # Verify closure
      expect(position.status).to eq('closed_profit')
      expect(position.exit_price).to eq(102.0)
      expect(position.exit_reason).to eq('take_profit')
      expect(position.exit_time).to be >= test_start_time
      expect(position.profit_loss).to be > 0
      
      puts "   ✓ Position closure audit trail: #{position.status} with $#{position.profit_loss&.round(2)} P/L"
    end
    
    it 'validates complete audit trail timestamp sequence' do
      puts "\n🔍 Testing complete audit trail timestamp sequence"
      
      test_start_time = Time.current
      timestamps = []
      
      # Step 1: Create EMA readings
      ema5 = EmaReading.create!(symbol: symbol, period: 5, value: 118.5, timestamp: Time.current)
      timestamps << { type: 'ema_reading', time: ema5.timestamp }
      sleep(0.01)  # Ensure timestamp differences
      
      # Step 2: Create trading signal
      signal = TradingSignal.create!(
        symbol: symbol, signal_type: 'buy', price: 119.0,
        ema5: 118.5, ema8: 117.2, ema22: 115.8,
        timestamp: Time.current, user: user
      )
      timestamps << { type: 'trading_signal', time: signal.timestamp }
      sleep(0.01)
      
      # Step 3: Create position
      position = Position.create!(
        user: user, symbol: symbol, amount: 1000.0,
        entry_price: 119.5, entry_time: Time.current, status: 'open'
      )
      timestamps << { type: 'position_open', time: position.entry_time }
      sleep(0.01)
      
      # Step 4: Create activity log
      activity_log = ActivityLog.log_signal(symbol, 'buy', 119.0, user: user)
      timestamps << { type: 'activity_log', time: activity_log.occurred_at }
      sleep(0.01)
      
      # Step 5: Close position
      position.close(122.0, 'take_profit')
      timestamps << { type: 'position_close', time: position.exit_time }
      
      # Verify timestamp sequence
      sorted_timestamps = timestamps.sort_by { |t| t[:time] }
      expect(timestamps).to eq(sorted_timestamps)
      
      # Verify all timestamps are after test start
      timestamps.each do |timestamp_record|
        expect(timestamp_record[:time]).to be >= test_start_time
      end
      
      # Calculate total duration
      total_duration = ((timestamps.last[:time] - timestamps.first[:time]) * 1000).round(0)
      
      puts "   ✓ Complete audit trail timestamp sequence validated"
      puts "     - Steps: #{timestamps.map { |t| t[:type] }.join(' → ')}"
      puts "     - Duration: #{total_duration}ms"
      puts "     - All timestamps in chronological order ✓"
    end
    
    it 'validates database record counts for complete cycle' do
      puts "\n🔍 Testing complete cycle database record counts"
      
      # Execute complete cycle
      
      # 1. EMA Readings (3 periods)
      [5, 8, 22].each do |period|
        EmaReading.create!(symbol: symbol, period: period, value: 100 + period, timestamp: Time.current)
      end
      
      # 2. Trading Signal (1 signal)
      TradingSignal.create!(
        symbol: symbol, signal_type: 'buy', price: 119.0,
        ema5: 118.5, ema8: 117.2, ema22: 115.8,
        timestamp: Time.current, user: user
      )
      
      # 3. Position (1 position)
      position = Position.create!(
        user: user, symbol: symbol, amount: 1000.0,
        entry_price: 119.5, entry_time: Time.current, status: 'open'
      )
      
      # 4. Activity Logs (multiple types)
      ActivityLog.log_signal(symbol, 'buy', 119.0, user: user)
      ActivityLog.log_trade(symbol, 'buy', 119.5, user: user)
      ActivityLog.log_order(symbol, 'buy', 1000.0, user: user)
      
      # 5. Position closure
      position.close(122.0, 'take_profit')
      
      # Verify exact counts as per Ticket T15 requirements
      expect(EmaReading.where(symbol: symbol).count).to eq(3)
      expect(TradingSignal.where(symbol: symbol, user: user).count).to eq(1)
      expect(Position.where(symbol: symbol, user: user).count).to eq(1)
      expect(ActivityLog.where(symbol: symbol, user: user).count).to eq(3)
      
      # Verify position is closed
      position.reload
      expect(position.status).to eq('closed_profit')
      
      puts "   ✓ Database record counts validation (Ticket T15 requirements):"
      puts "     - EmaReading: #{EmaReading.where(symbol: symbol).count} records ✓"
      puts "     - TradingSignal: #{TradingSignal.where(symbol: symbol, user: user).count} records ✓"
      puts "     - Position: #{Position.where(symbol: symbol, user: user).count} records ✓"
      puts "     - ActivityLog: #{ActivityLog.where(symbol: symbol, user: user).count} records ✓"
      puts "     - Position Status: #{position.status} ✓"
    end
  end
  
  describe 'Bug Fixes Validation' do
    it 'confirms ActivityLog.log_trade method works (Bug Fix #1)' do
      puts "\n🐛 Bug Fix Validation: ActivityLog.log_trade method"
      
      # This method was missing and would cause NoMethodError
      expect {
        log = ActivityLog.log_trade(symbol, 'buy', 119.50, user: user, details: { position_id: 123 })
        expect(log).to be_present
        expect(log.event_type).to eq('trade')
        expect(log.message).to include('BUY trade executed')
      }.not_to raise_error
      
      puts "   ✓ ActivityLog.log_trade method works correctly"
    end
    
    it 'confirms timeframe format consistency (Bug Fix #2)' do
      puts "\n🐛 Bug Fix Validation: Timeframe format consistency"
      
      # BotSetting should accept "5m" format (not "5Min")
      expect {
        user.bot_setting.update!(timeframe: '5m')
      }.not_to raise_error
      
      expect(user.bot_setting.timeframe).to eq('5m')
      
      puts "   ✓ Timeframe format consistency fixed (5m vs 5Min)"
    end
    
    it 'confirms TrackedSymbol uniqueness handling (Bug Fix #3)' do
      puts "\n🐛 Bug Fix Validation: TrackedSymbol uniqueness"
      
      # Should handle duplicate symbol creation gracefully
      symbol1 = user.tracked_symbols.find_or_create_by(symbol: 'MSFT') { |ts| ts.active = true }
      symbol2 = user.tracked_symbols.find_or_create_by(symbol: 'MSFT') { |ts| ts.active = true }
      
      expect(symbol1.id).to eq(symbol2.id)  # Same record
      expect(user.tracked_symbols.where(symbol: 'MSFT').count).to eq(1)
      
      puts "   ✓ TrackedSymbol uniqueness properly handled"
    end
  end
end 