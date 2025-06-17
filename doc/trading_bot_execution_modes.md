# Trading Bot Execution Modes

## Overview
The TradingBotService now supports both asynchronous and synchronous execution modes to provide flexibility while maintaining backward compatibility.

## Execution Modes

### Asynchronous Mode (Default)
- **Usage**: `bot.run()` or `bot.run(async: true)`
- **Behavior**: When trading signals are detected, ExecuteTradeJob is enqueued for background processing
- **Benefits**: 
  - Non-blocking signal detection
  - Better performance for real-time systems
  - Scalable background job processing
- **Requirements**: Background job processor (e.g., Sidekiq) must be running

### Synchronous Mode (Legacy)
- **Usage**: `bot.run(async: false)`
- **Behavior**: When trading signals are detected, trades are executed immediately
- **Benefits**:
  - Immediate trade execution
  - No background job infrastructure required
  - Simpler error handling and debugging
- **Use Cases**: Rake tasks, user-triggered actions, development/testing

## Application Integration

### Components Using Sync Mode
1. **Rake Tasks** (`lib/tasks/trading_bot.rake`)
   ```ruby
   bot.run(async: false)  # Immediate execution for CLI tasks
   ```

2. **UserTradingService** (`app/services/user_trading_service.rb`)
   ```ruby
   @trading_bot_service.run(async: false)  # User-triggered trades
   ```

### Components Using Async Mode
1. **Background Jobs** (MarketPingJob, automated trading)
   ```ruby
   bot.run()  # Default async mode for automated systems
   ```

## Job Infrastructure

### ExecuteTradeJob
- **Purpose**: Handles asynchronous trade execution
- **Parameters**: symbol, user_id, trade_amount
- **Error Handling**: Logs errors and raises for retry mechanisms
- **Integration**: Calls TradingBotService.execute_trade internally

### Benefits of Async Mode
- **Performance**: Signal detection doesn't block on trade execution
- **Scalability**: Multiple signals can be processed concurrently
- **Reliability**: Job retry mechanisms handle transient failures
- **Monitoring**: Background job status tracking

## Migration Notes

### Backward Compatibility
- All existing integrations have been updated to use sync mode
- No breaking changes to public API
- Same return values and error handling patterns

### Future Considerations
- Consider migrating automated systems to async mode for better performance
- Background job monitoring should be implemented for production
- Error handling strategies should be reviewed for async operations

## Testing
- Integration tests cover both execution modes
- 13 test scenarios validate async/sync behavior
- No regressions in existing functionality 