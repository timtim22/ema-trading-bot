# 🎯 Client Demo UI Checklist

## Quick Pre-Demo Test (15 minutes)

### ✅ **Application Startup**
- [ ] `rails server` starts without errors
- [ ] `bundle exec sidekiq` running (if using background jobs)
- [ ] Navigate to `http://localhost:3000`
- [ ] Login page loads correctly
- [ ] Login with test user succeeds

### ✅ **Dashboard Core Functionality**
- [ ] Main dashboard loads in < 3 seconds
- [ ] Bot status shows correctly (STOPPED initially)
- [ ] Current symbol displayed (AAPL by default)
- [ ] Charts render without errors

### ✅ **Bot Controls**
- [ ] "Start Bot" button clicks and changes to "Stop Bot"
- [ ] Status indicator changes color (green for running)
- [ ] Success notification appears
- [ ] "Stop Bot" button works and reverts status
- [ ] Bot state persists after page refresh

### ✅ **Real-Time Data**
- [ ] Price chart displays current data
- [ ] EMA lines visible (5, 8, 22)
- [ ] Chart updates with new data (wait 30-60 seconds)
- [ ] No JavaScript errors in browser console (F12)

### ✅ **Signal Detection**
- [ ] Current signal section shows data
- [ ] EMA values display numerically
- [ ] Uptrend/Crossover status indicators work
- [ ] Signal status updates ("WAIT" or "BUY")

### ✅ **Settings Panel**
- [ ] Can access user settings/preferences
- [ ] Risk management fields editable
- [ ] Settings save successfully
- [ ] Confirmation message appears

### ✅ **Responsive Design**
- [ ] Resize browser window - elements adapt
- [ ] Mobile view (F12 → Device emulation) functional
- [ ] No horizontal scrolling
- [ ] All controls accessible on smaller screens

### ✅ **Error Handling**
- [ ] During market closed hours - appropriate message
- [ ] Invalid symbol handling
- [ ] Network connection issues handled gracefully

## 🚨 **Demo Killer Issues - Stop if Found:**
- ❌ Charts don't load or show errors
- ❌ Bot controls don't work
- ❌ Page load time > 5 seconds
- ❌ JavaScript errors preventing functionality
- ❌ Real-time updates not working
- ❌ Mobile view completely broken

## 📊 **Demo Data Setup**
```bash
# Run in Rails console before demo
rails console

# Create sample positions for demonstration
user = User.first
Position.create!(user: user, symbol: "AAPL", amount: 1000, entry_price: 150.0, current_price: 152.5, status: 'open', entry_time: 1.hour.ago)
Position.create!(user: user, symbol: "MSFT", amount: 1000, entry_price: 300.0, current_price: 298.5, status: 'open', entry_time: 30.minutes.ago)
```

## 🎬 **Demo Script Flow**
1. **Opening (30s)**: "Here's our EMA trading bot dashboard"
2. **Strategy (60s)**: "We use 5, 8, and 22 period EMAs with crossover signals"
3. **Live Demo (2m)**: Start bot, show real-time data, explain signals
4. **Risk Management (60s)**: "Configurable profit/loss thresholds"
5. **Positions (30s)**: "Real-time P&L tracking and position management"

## ⏰ **Timeline**
- **30 min before demo**: Complete full checklist
- **15 min before demo**: Quick health check
- **5 min before demo**: Final browser/connection test

## 💻 **Browser Setup**
- Primary demo browser: **Chrome**
- Backup browser tab ready
- Developer tools closed (unless showing technical details)
- Zoom level: 100% for clarity
- Ad blockers: Disabled
- Screen sharing: Tested

## 📱 **Demo Environment**
- **Development**: `http://localhost:3000`
- **Staging**: `https://your-staging-url.com`
- **Production**: `https://your-production-url.com`

Use the environment that's most stable and has the best demo data.

---

**✅ All checks passed? You're ready for the client demo! 🚀**

**❌ Issues found? Address critical items before proceeding.** 