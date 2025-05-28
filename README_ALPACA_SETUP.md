# Alpaca API Setup Guide

## 1. Get Your Alpaca API Credentials

1. Sign up for a free Alpaca account at [alpaca.markets](https://alpaca.markets)
2. Go to your dashboard and navigate to "API Keys"
3. Generate new API keys for paper trading (sandbox)
4. Copy your API Key ID and Secret Key

## 2. Set Environment Variables

Add these to your `.env` file (create one if it doesn't exist):

```bash
# Alpaca API Credentials (Paper Trading)
ALPACA_API_KEY_ID=your_api_key_id_here
ALPACA_API_SECRET_KEY=your_secret_key_here
```

**Important:** Never commit your `.env` file to git. It should already be in your `.gitignore`.

## 3. Test Your Integration

Run this command to test your Alpaca connection:

```bash
rails runner "puts AlpacaDataService.new.fetch_bars('AAPL', limit: 1).inspect"
```

## 4. Create Test Positions with Real Data

```bash
# Clear any existing test positions
rails positions:clear_test

# Create new positions with real Alpaca market data
rails positions:create_test
```

## 5. Start the Application

```bash
# Start both Rails server and Sidekiq worker
bin/dev
```

## 6. View Your Dashboard

Open [http://localhost:3000/dashboard](http://localhost:3000/dashboard) and:

1. Click "Start Bot" to begin receiving real market data
2. Watch the "Data Source" indicator - it should show "Alpaca API" (green) for real data
3. If Alpaca fails, it will fallback to "Simulated" (yellow) data

## 7. Create Real Trading Positions (Optional)

**⚠️ Warning:** This will place actual orders in your Alpaca paper trading account!

```bash
# Create a real trading position for $100 of AAPL
rails positions:create_real[AAPL,100]
```

## Troubleshooting

### Data Source Shows "Simulated" Instead of "Alpaca API"

1. Check your environment variables are set correctly
2. Verify your API keys are valid
3. Check the Rails logs for error messages:
   ```bash
   tail -f log/development.log
   ```

### Rate Limiting

Alpaca has rate limits. If you hit them:
- Free tier: 200 requests per minute
- The app will automatically fall back to simulated data
- Check logs for rate limit warnings

### Market Hours

Alpaca provides real-time data during market hours (9:30 AM - 4:00 PM ET, Monday-Friday).
Outside market hours, you'll get the last available data.

## Features Now Using Real Alpaca Data

✅ **Market Data Chart**: Real OHLC candlestick data  
✅ **EMA Calculations**: Based on real historical prices  
✅ **Position Creation**: Uses current market prices  
✅ **Real-time Updates**: Live price feeds every 10 seconds  
✅ **Trading Orders**: Can place real orders via Alpaca API  

## Next Steps

- Monitor your positions in real-time
- Implement trading signals based on EMA crossovers
- Add more sophisticated risk management
- Scale to multiple symbols 