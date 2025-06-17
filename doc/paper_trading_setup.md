# Paper Trading Setup Guide

## Overview

Your EMA Trading Bot now supports **Paper Trading** - a safe way to test your trading strategy with simulated money before risking real capital. Paper trading uses Alpaca's free simulation environment with real market data but fake money.

## What is Paper Trading?

Paper trading is:
- **Simulated trading** with fake money ($100,000 by default)
- **Real market data** from Alpaca's data feed
- **Identical API behavior** to live trading
- **Risk-free testing** of your EMA strategy
- **Performance tracking** with detailed metrics

## Current Configuration

Your bot is **already configured for paper trading** by default! Here's what's set up:

```ruby
# config/initializers/alpaca.rb
PAPER_TRADING = ENV.fetch('PAPER_TRADING', 'true').downcase == 'true'
ALPACA_ENDPOINT = 'https://paper-api.alpaca.markets'  # Paper trading endpoint
```

## Quick Start

### 1. Get Alpaca Paper Trading API Keys

1. Go to [Alpaca Paper Trading Dashboard](https://app.alpaca.markets/paper/dashboard/overview)
2. Sign up for a free account (no deposit required)
3. Generate your API keys
4. Set these environment variables:

```bash
# Paper Trading API Keys (FREE)
PAPER_TRADING=true
ALPACA_API_KEY_ID=your_paper_trading_key_id
ALPACA_API_SECRET_KEY=your_paper_trading_secret
```

### 2. Configure Your Paper Trading Balance

```bash
# Optional: Set initial paper trading balance (default: $100,000)
PAPER_TRADING_BALANCE=100000
```

### 3. Start Trading

Your bot will now:
- Use **simulated money** only
- Place **fake orders** that get filled based on real market prices
- Track **performance metrics** without any financial risk
- Log all activities for analysis

## Environment Variables

```bash
# ===========================================
# PAPER TRADING CONFIGURATION
# ===========================================
PAPER_TRADING=true                    # Enable paper trading mode
PAPER_TRADING_BALANCE=100000         # Initial balance ($100k default)

# ===========================================
# ALPACA API KEYS (Paper Trading)
# ===========================================
ALPACA_API_KEY_ID=your_key_here      # Get from Alpaca paper dashboard
ALPACA_API_SECRET_KEY=your_secret_here

# ===========================================
# TRADING STRATEGY
# ===========================================
DEFAULT_SYMBOL=AAPL                  # Symbol to trade
TRADE_AMOUNT=1000                    # Dollar amount per trade
PROFIT_PERCENTAGE=1.0                # Take profit at +1%
LOSS_PERCENTAGE=1.0                  # Stop loss at -1%
CONFIRMATION_BARS=3                  # Wait 3 bars for confirmation
```

## Paper Trading Features

### Dashboard Integration

Your dashboard now shows:
- **Trading Mode** indicator (Paper/Live)
- **Paper account balance** and buying power
- **Simulated positions** and their P&L
- **Paper trading performance** metrics
- **Recent paper orders** and fills

### API Endpoints

New endpoints for paper trading:
```
GET  /dashboard/paper_trading_info    # Get paper account info
POST /dashboard/toggle_trading_mode   # Switch modes (requires restart)
```

### Safety Features

- **Visual indicators** showing you're in paper mode
- **Validation checks** to ensure proper configuration
- **Clear warnings** when switching to live trading
- **Separate API keys** for paper vs live trading

## Testing Your Strategy

### 1. Monitor Performance

Track these key metrics:
- **Total Return**: Overall profit/loss percentage
- **Win Rate**: Percentage of profitable trades
- **Active Positions**: Current holdings
- **Day Trade Count**: Pattern day trader tracking
- **Unrealized P&L**: Paper gains/losses on open positions

### 2. Analyze Results

Your paper trading will show:
- How your EMA crossover strategy performs
- Whether 3-bar confirmation reduces false signals
- If 1% profit/loss targets are appropriate
- How often you hit pattern day trading limits

### 3. Optimize Settings

Based on paper results, adjust:
- `PROFIT_PERCENTAGE` and `LOSS_PERCENTAGE`
- `CONFIRMATION_BARS` count
- `TRADE_AMOUNT` size
- `DEFAULT_TIMEFRAME` for analysis

## Switching to Live Trading

⚠️ **WARNING: Only after thorough paper testing!**

To switch to live trading:

1. **Get live API keys** from [Alpaca Live Dashboard](https://app.alpaca.markets/brokerage/dashboard/overview)
2. **Fund your account** with real money
3. **Update environment variables**:
   ```bash
   PAPER_TRADING=false
   ALPACA_API_KEY_ID=your_live_key_id
   ALPACA_API_SECRET_KEY=your_live_secret
   ```
4. **Restart the application**
5. **Start with small amounts** to verify everything works

## Paper Trading Limitations

Alpaca's paper trading does NOT simulate:
- Market impact of large orders
- Price slippage due to latency
- Order queue position for limit orders
- Regulatory fees
- Dividends
- Borrowing costs for short selling

These factors matter in live trading but are acceptable approximations for strategy testing.

## Resetting Your Paper Account

To reset your paper trading account:

1. Go to [Alpaca Paper Dashboard](https://app.alpaca.markets/paper/dashboard/overview)
2. Click your account number in upper left
3. Select "Open New Paper Account"
4. Generate new API keys for the fresh account
5. Update your environment variables

## Best Practices

### For Paper Trading
- Run the bot for **at least 1-2 weeks** to gather meaningful data
- Test during **different market conditions** (trending, sideways, volatile)
- Monitor **all timeframes** you plan to use (1m, 5m, 15m)
- Analyze **both winning and losing** trades

### Before Going Live
- Achieve **consistent profitability** in paper trading
- Understand **why trades win or lose**
- Test **risk management** (stop losses, position sizing)
- Verify **all features work** as expected
- Start with **small real amounts** ($100-500) initially

## Troubleshooting

### Common Issues

1. **"Missing API Keys" Error**
   - Ensure `ALPACA_API_KEY_ID` and `ALPACA_API_SECRET_KEY` are set
   - Use paper trading keys from the paper dashboard

2. **"Wrong Endpoint" Error**
   - Verify `PAPER_TRADING=true` is set
   - Check that endpoint shows `paper-api.alpaca.markets`

3. **"Orders Not Filling" Warning**
   - Paper orders fill based on real market conditions
   - Market orders fill immediately, limit orders when price reached
   - Check if the market is open

4. **"No Market Data" Error**
   - Alpaca paper accounts get free IEX data
   - Data may be delayed 15 minutes
   - Ensure symbol is valid and traded

### Getting Help

- Check the Rails logs for detailed error messages
- Visit [Alpaca Documentation](https://docs.alpaca.markets/docs/paper-trading)
- Join [Alpaca Community Slack](https://alpaca.markets/slack)

## Summary

Your EMA Trading Bot now includes comprehensive paper trading support:

✅ **Safe Testing** - No real money at risk  
✅ **Real Data** - Live market prices and conditions  
✅ **Full Features** - All bot functionality available  
✅ **Performance Tracking** - Detailed metrics and analysis  
✅ **Easy Setup** - Already configured and ready to use  

Start testing your strategy today with paper trading before moving to live trading! 