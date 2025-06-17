# Manual Testing Guide: EMA Trading Bot Core Logic

## Overview
This guide provides step-by-step instructions to manually test the core trading bot logic before the client demo. Focus is on validating calculations, signal detection, and expected outcomes rather than performance or UI.

## Prerequisites
- Rails console access: `rails console`
- Test environment with sample data
- Mock services for Alpaca API calls during testing

## Core Testing Scenarios

### 1. EMA Calculation & Signal Detection

#### Test Scenario 1.1: Basic EMA Calculations
```ruby
# In Rails console
user = User.first || User.create!(email: "test@example.com", password: "password123")
symbol = "AAPL"
trading_service = TradingBotService.new(symbol, "5Min", user)

# Test with known price data
test_closes = [150.0, 151.0, 152.0, 151.5, 152.5, 153.0, 152.0, 153.5, 154.0, 155.0, 
               156.0, 157.0, 158.0, 159.0, 160.0, 159.5, 160.5, 161.0, 162.0, 163.0, 
               164.0, 165.0]

# Calculate EMAs manually
ema_result = trading_service.calculate_emas(test_closes)
puts "EMA-5: #{ema_result[:ema5]}"
puts "EMA-8: #{ema_result[:ema8]}"
puts "EMA-22: #{ema_result[:ema22]}"

# Verify trend detection
uptrend = EmaCalculatorService.uptrend?(ema_result[:ema5], ema_result[:ema8], ema_result[:ema22])
puts "Uptrend detected: #{uptrend}"
```

**Expected Results:**
- EMA-5 should be highest (most reactive)
- EMA-8 should be middle value
- EMA-22 should be lowest (most stable)
- Uptrend should be `true` for rising prices

#### Test Scenario 1.2: Crossover Signal Detection
```ruby
# Test crossover scenario - EMA-5 crossing above EMA-8
# Create data that goes from downtrend to uptrend
crossover_data = [
  # Declining phase (EMA-5 < EMA-8)
  100.0, 99.8, 99.5, 99.2, 99.0, 98.8, 98.5, 98.2, 98.0, 97.8,
  97.5, 97.2, 97.0, 96.8, 96.5, 96.2, 96.0,
  # Rising phase (EMA-5 > EMA-8) - should trigger crossover
  96.5, 97.0, 98.0, 99.5, 101.0, 103.0
]

ema_data = trading_service.calculate_emas(crossover_data)
crossover = EmaCalculatorService.confirmed_crossover?(ema_data[:ema5_values], ema_data[:ema8_values])
puts "Crossover confirmed: #{crossover}"
puts "EMA-5 values: #{ema_data[:ema5_values].last(5)}"
puts "EMA-8 values: #{ema_data[:ema8_values].last(5)}"
```

**Expected Results:**
- Crossover should be `true`
- Last few EMA-5 values should be above EMA-8 values
- Signal detection should work correctly

### 2. Market Hours & Holiday Detection

#### Test Scenario 2.1: Weekend Detection
```ruby
# Test weekend detection
trading_service = TradingBotService.new("AAPL", "5Min", user)

# Mock a Saturday
allow(Time).to receive(:current).and_return(Time.parse("2024-01-06 10:00:00 EST")) # Saturday
market_error = trading_service.check_market_hours
puts "Weekend error: #{market_error}"

# Mock a Sunday  
allow(Time).to receive(:current).and_return(Time.parse("2024-01-07 10:00:00 EST")) # Sunday
market_error = trading_service.check_market_hours
puts "Sunday error: #{market_error}"

# Mock a weekday during market hours
allow(Time).to receive(:current).and_return(Time.parse("2024-01-08 11:00:00 EST")) # Monday
market_error = trading_service.check_market_hours
puts "Monday during hours: #{market_error.nil? ? 'Market OPEN' : market_error}"
```

**Expected Results:**
- Weekend days should return "Outside market hours: weekend"
- Weekday during hours should return `nil` (market open)

#### Test Scenario 2.2: Holiday Detection
```ruby
# Test major holidays
holidays_to_test = [
  ["2024-01-01", "New Year's Day"],
  ["2024-07-04", "Independence Day"], 
  ["2024-12-25", "Christmas Day"],
  ["2024-01-15", "MLK Day"], # Third Monday in January
  ["2024-11-28", "Thanksgiving"] # Fourth Thursday in November
]

holidays_to_test.each do |date_str, holiday_name|
  test_time = Time.parse("#{date_str} 11:00:00 EST")
  allow(Time).to receive(:current).and_return(test_time)
  
  market_error = trading_service.check_market_hours
  puts "#{date_str} (#{holiday_name}): #{market_error}"
end
```

**Expected Results:**
- All holidays should return "Outside market hours: holiday (Holiday Name)"

### 3. Trade Execution Logic

#### Test Scenario 3.1: Sync vs Async Execution
```ruby
# Test synchronous execution (immediate trade)
trading_service = TradingBotService.new("AAPL", "5Min", user)

# Mock successful market data fetch
mock_alpaca = instance_double('AlpacaDataService')
allow(mock_alpaca).to receive(:fetch_closes_with_timestamp).and_return({
  symbol: "AAPL",
  timeframe: "5Min", 
  closes: [150.0, 151.0, 152.0, 153.0, 154.0, 155.0, 154.0, 155.0, 156.0, 
           157.0, 158.0, 159.0, 160.0, 161.0, 162.0, 161.0, 162.0, 163.0, 
           165.0, 168.0, 170.0, 175.0], # Strong uptrend with crossover
  timestamp: Time.current
})
allow(mock_alpaca).to receive(:save_ema_readings).and_return(true)
trading_service.instance_variable_set(:@alpaca_service, mock_alpaca)

# Mock successful order placement
mock_order_service = instance_double('OrderService')
allow(mock_order_service).to receive(:place_buy_order_with_safety).and_return({
  primary_order_id: 'test_order_123',
  symbol: 'AAPL',
  amount: 1000.0,
  fill_price: 175.0,
  fill_qty: 5.71,
  status: 'filled',
  take_profit_order_id: 'tp_456',
  stop_loss_order_id: 'sl_789'
})
trading_service.instance_variable_set(:@order_service, mock_order_service)

# Allow market hours to pass
allow(trading_service).to receive(:check_market_hours).and_return(nil)

# Test sync execution
result = trading_service.run(async: false)
puts "Sync execution result: #{result}"

# Check if position was created
position = Position.last
puts "Position created: #{position&.symbol} at $#{position&.entry_price}"
```

**Expected Results:**
- `result` should be `true`
- Position should be created with correct details
- No background jobs should be enqueued

#### Test Scenario 3.2: Risk Management Settings
```ruby
# Test different risk percentages
user.bot_setting.update!(
  profit_percentage: 2.0,  # 2% profit target
  loss_percentage: 1.5,    # 1.5% stop loss
  confirmation_bars: 2     # 2-bar confirmation
)

trading_service = TradingBotService.new("AAPL", "5Min", user)
puts "Profit target: #{trading_service.instance_variable_get(:@profit_percentage) * 100}%"
puts "Stop loss: #{trading_service.instance_variable_get(:@loss_percentage) * 100}%"
puts "Confirmation bars: #{trading_service.instance_variable_get(:@confirmation_bars)}"
```

**Expected Results:**
- Settings should match user configuration
- Service should use user-specific parameters

### 4. Position Management & Exit Conditions

#### Test Scenario 4.1: Take Profit Logic
```ruby
# Create a test position
position = Position.create!(
  user: user,
  symbol: "AAPL",
  amount: 1000.0,
  entry_price: 150.0,
  status: 'open',
  entry_time: Time.current
)

# Test take profit at +2%
current_price = 153.0 # 2% profit
profit_pct = (current_price - position.entry_price) / position.entry_price
puts "Current profit: #{(profit_pct * 100).round(2)}%"

# Check if position should close
user_trading_service = UserTradingService.new(user, "AAPL")
should_close = user_trading_service.check_and_close_positions(current_price)
puts "Position closed: #{should_close}"

position.reload
puts "Position status: #{position.status}"
```

**Expected Results:**
- Profit calculation should be accurate
- Position should close when profit target is reached

#### Test Scenario 4.2: Stop Loss Logic
```ruby
# Create another test position
position = Position.create!(
  user: user,
  symbol: "MSFT",
  amount: 1000.0,
  entry_price: 300.0,
  status: 'open',
  entry_time: Time.current
)

# Test stop loss at -1.5%
current_price = 295.5 # 1.5% loss
loss_pct = (current_price - position.entry_price) / position.entry_price
puts "Current loss: #{(loss_pct * 100).round(2)}%"

user_trading_service = UserTradingService.new(user, "MSFT")
should_close = user_trading_service.check_and_close_positions(current_price)
puts "Position closed: #{should_close}"

position.reload
puts "Position status: #{position.status}"
```

**Expected Results:**
- Loss calculation should be accurate
- Position should close when stop loss is triggered

### 5. Error Handling & Retry Logic

#### Test Scenario 5.1: API Failure Retry
```ruby
trading_service = TradingBotService.new("AAPL", "5Min", user)

# Mock API failures followed by success
call_count = 0
mock_alpaca = instance_double('AlpacaDataService')
allow(mock_alpaca).to receive(:fetch_closes_with_timestamp) do
  call_count += 1
  if call_count <= 2
    # First two calls fail
    nil
  else
    # Third call succeeds
    {
      symbol: "AAPL",
      timeframe: "5Min",
      closes: Array.new(22) { |i| 150.0 + i * 0.1 },
      timestamp: Time.current
    }
  end
end
allow(mock_alpaca).to receive(:last_error).and_return("Temporary API error")
allow(mock_alpaca).to receive(:save_ema_readings).and_return(true)
trading_service.instance_variable_set(:@alpaca_service, mock_alpaca)

# Allow market hours
allow(trading_service).to receive(:check_market_hours).and_return(nil)

start_time = Time.current
result = trading_service.fetch_market_data(max_retries: 3)
end_time = Time.current

puts "Retry result: #{result ? 'SUCCESS' : 'FAILED'}"
puts "Calls made: #{call_count}"
puts "Time taken: #{(end_time - start_time).round(2)} seconds"
```

**Expected Results:**
- Should succeed after retries
- Should demonstrate exponential backoff
- Call count should show retry attempts

### 6. Bot State Management

#### Test Scenario 6.1: Start/Stop Bot Control
```ruby
# Test bot state management
symbol = "AAPL"

# Start bot
bot_state = BotState.start!(symbol)
puts "Bot started: #{bot_state.running?}"
puts "Start time: #{bot_state.started_at}"

# Stop bot
bot_state = BotState.stop!(symbol)
puts "Bot stopped: #{bot_state.running?}"
puts "Stop time: #{bot_state.stopped_at}"

# Verify trading service respects bot state
trading_service = TradingBotService.new(symbol, "5Min", user)
# Bot should not execute trades when stopped
# (This would be tested in integration, but state is verifiable)
```

**Expected Results:**
- Bot state should toggle correctly
- Timestamps should be recorded

### 7. Data Validation & Edge Cases

#### Test Scenario 7.1: Insufficient Data
```ruby
# Test with insufficient data for EMA calculation
trading_service = TradingBotService.new("TEST", "5Min", user)

# Too few data points for 22-period EMA
insufficient_data = [100.0, 101.0, 102.0] # Only 3 points

ema_result = trading_service.calculate_emas(insufficient_data)
puts "EMA result with insufficient data: #{ema_result}"

# Should handle gracefully without errors
```

**Expected Results:**
- Should return `nil` or handle gracefully
- No errors should be raised

#### Test Scenario 7.2: Flat/Sideways Market
```ruby
# Test with flat market data (no trend)
flat_data = Array.new(25, 100.0) # All same price

ema_result = trading_service.calculate_emas(flat_data)
puts "Flat market EMAs:"
puts "EMA-5: #{ema_result[:ema5]}"
puts "EMA-8: #{ema_result[:ema8]}"
puts "EMA-22: #{ema_result[:ema22]}"

uptrend = EmaCalculatorService.uptrend?(ema_result[:ema5], ema_result[:ema8], ema_result[:ema22])
crossover = EmaCalculatorService.confirmed_crossover?(ema_result[:ema5_values], ema_result[:ema8_values])

puts "Uptrend in flat market: #{uptrend}"
puts "Crossover in flat market: #{crossover}"
```

**Expected Results:**
- All EMAs should be approximately equal
- No uptrend or crossover should be detected

## Testing Checklist

### Core Logic ✓
- [ ] EMA calculations are mathematically correct
- [ ] Crossover detection works with various data patterns
- [ ] Uptrend detection follows EMA-5 > EMA-8 > EMA-22 rule
- [ ] 3-bar confirmation prevents false signals

### Risk Management ✓
- [ ] Profit targets trigger correctly at user-defined percentages
- [ ] Stop losses activate at user-defined percentages  
- [ ] Position sizing respects trade amount settings
- [ ] Multiple positions are prevented for same symbol/user

### Market Conditions ✓
- [ ] Weekend trading is blocked
- [ ] Major holidays are detected and trading blocked
- [ ] Market hours (9:30 AM - 4:00 PM ET) are enforced
- [ ] After-hours trading is blocked

### Error Handling ✓
- [ ] API failures trigger exponential backoff retries
- [ ] Rate limiting is handled with extended delays
- [ ] Network timeouts recover gracefully
- [ ] Invalid data is handled without crashes

### Data Integrity ✓
- [ ] Insufficient data scenarios are handled
- [ ] Flat/sideways markets don't trigger false signals
- [ ] Race conditions in position creation are prevented
- [ ] Database transactions ensure atomicity

### Bot Control ✓  
- [ ] Start/stop commands work correctly
- [ ] Graceful shutdown preserves in-flight orders
- [ ] Bot state is persisted correctly
- [ ] Multiple symbol management works

## Demo Preparation

Before the client demo, ensure:

1. **Test all scenarios above** with expected results matching
2. **Verify calculations** manually for at least one complete cycle
3. **Check edge cases** don't cause crashes or unexpected behavior
4. **Validate risk management** with real percentage calculations
5. **Confirm market hours** detection works for current date/time

## Quick Demo Script

For the client demo, prepare this sequence:

```ruby
# 1. Show EMA calculation
user = User.first
trading_service = TradingBotService.new("AAPL", "5Min", user)

# 2. Demo signal detection with clear uptrend data
demo_data = [145, 146, 147, 146, 148, 149, 147, 150, 151, 149, 152, 153, 151, 154, 155, 153, 156, 157, 155, 158, 160, 162]
emas = trading_service.calculate_emas(demo_data)
puts "Current EMAs - 5: #{emas[:ema5].round(2)}, 8: #{emas[:ema8].round(2)}, 22: #{emas[:ema22].round(2)}"

uptrend = EmaCalculatorService.uptrend?(emas[:ema5], emas[:ema8], emas[:ema22])
crossover = EmaCalculatorService.confirmed_crossover?(emas[:ema5_values], emas[:ema8_values])

puts "Signal Detection: Uptrend=#{uptrend}, Crossover=#{crossover}"
puts "Trade Signal: #{uptrend && crossover ? 'BUY' : 'WAIT'}"

# 3. Show risk management
puts "\nRisk Management:"
puts "Profit Target: +#{(trading_service.instance_variable_get(:@profit_percentage) * 100).round(1)}%"
puts "Stop Loss: -#{(trading_service.instance_variable_get(:@loss_percentage) * 100).round(1)}%"
puts "Trade Amount: $#{trading_service.instance_variable_get(:@trade_amount)}"
```

This demonstrates the core logic working correctly with clear, understandable output for the client. 