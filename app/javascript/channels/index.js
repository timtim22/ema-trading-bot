// Import all the channels to be used by Action Cable
console.log("Loading channels/index.js...")

// Load consumer and market channel
import "./consumer"
import "./market_channel"
import "./notifications_channel"

console.log("Channels loaded successfully")
import "./trading_signals_channel"
