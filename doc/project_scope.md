EMA 5–8 Strategy Basics
What are EMAs?

5-period EMA: a weighted average of the last 5 bars, very quick to react to recent price moves.

8-period EMA: averages the last 8 bars, smoothing out more of the noise but still responsive.

Crossover Signals

Bullish (Buy): when the 5-EMA crosses above the 8-EMA → suggests buyers are taking control.

Bearish (Sell or Exit): when the 5-EMA crosses below the 8-EMA → suggests sellers are gaining momentum.

When to Enter & Exit

Entry: the moment of crossover—ideally after a brief pause (we use a 3-bar confirmation to avoid false alarms).

Exit: either when the opposite crossover occurs, or sooner via your +1% take-profit / –1% stop-loss guardrails.

Timeframe

Works best on shorter charts (1-, 5- or 15-minute bars) where momentum shifts are most visible.

Risk Management

Position sizing: $1,000 per trade, sent as a market order in dollar value.

Stop-loss: immediate market exit at –1% to cap losses.

Take-profit: stop-limit at +1% so you lock in at least 1% but can ride further gains.



Project Scope

Configurable polling

Every X minutes (default 5-min; switch to 1-min via .env), fetch the pre-computed EMA-5 and EMA-8 values straight from your data provider—no manual calculations needed.

3-bar confirmation

Watch for the 5-EMA > 8-EMA crossover, then ensure that condition holds for three consecutive bars before we act.

Trade entry

On confirmation, send a $1,000 market-buy order (broker handles the share count).

Auto-exits

Take-profit: place a +1% stop-limit.

Stop-loss: place a –1% market-sell.

Error handling & alerts

Retries with exponential back-off on API failures.

Flags any order unfilled after 2 minutes for manual review.

Full audit trail

Logs every bar fetched, crossover check, order request/response, and fill event with timestamps.

Admin dashboard

Start/stop toggle, live EMA-5/8 view, open/closed trades with P/L, and symbol management—all in one screen.

.ENV-driven settings

EMA periods, confirmation bar count, profit/loss thresholds, trade size, and polling interval are all tweakable without code changes.