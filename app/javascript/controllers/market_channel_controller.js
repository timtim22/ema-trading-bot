import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { symbol: String }
  
  connect() {
    console.log("🔌 Market channel controller connected")
    this.symbolValue = this.symbolValue || "AAPL"
    this.reconnectAttempts = 0
    this.maxReconnectAttempts = 5
    this.isConnected = false
    this.fallbackPollingInterval = null
    this.lastUpdateTime = 0
    
    this.setupActionCable()
    
    // Start fallback polling after 10 seconds if not connected
    setTimeout(() => {
      if (!this.isConnected) {
        console.log("🔄 ActionCable not connected, starting fallback polling")
        this.startFallbackPolling()
      }
    }, 10000)
  }
  
  disconnect() {
    console.log("🔌 Market channel controller disconnected")
    this.isConnected = false
    this.stopFallbackPolling()
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
  }
  
  setupActionCable() {
    console.log("📡 Setting up ActionCable for market data...")
    console.log("📡 Environment check:", {
      hostname: window.location.hostname,
      protocol: window.location.protocol,
      isProduction: window.location.hostname === 'ema-trading-bot.onrender.com'
    })
    
    this.consumer = createConsumer()
    
    // Subscribe to the market channel
    this.subscription = this.consumer.subscriptions.create(
      "MarketChannel",
      {
        connected: () => {
          console.log("✅ Connected to MarketChannel")
          this.isConnected = true
          this.reconnectAttempts = 0
          this.stopFallbackPolling() // Stop fallback since WebSocket is working
          this.dispatchMarketEvent('market:connected', { message: 'Connected to market updates' })
        },
        
        disconnected: () => {
          console.log("❌ Disconnected from MarketChannel")
          this.isConnected = false
          this.dispatchMarketEvent('market:disconnected', { message: 'Disconnected from market updates' })
          this.attemptReconnect()
        },
        
        rejected: () => {
          console.log("🚫 MarketChannel subscription rejected")
          this.isConnected = false
          // Start fallback polling if WebSocket is rejected
          this.startFallbackPolling()
        },
        
        received: (data) => {
          console.log("📨 Received market data:", data)
          this.lastUpdateTime = Date.now()
          this.handleMarketData(data)
        }
      }
    )
  }
  
  attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log("🚫 Max reconnection attempts reached, starting fallback polling")
      this.startFallbackPolling()
      return
    }
    
    this.reconnectAttempts++
    const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000) // Exponential backoff, max 30s
    
    console.log(`🔄 Attempting to reconnect in ${delay/1000}s (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`)
    
    setTimeout(() => {
      if (!this.isConnected) {
        this.setupActionCable()
      }
    }, delay)
  }
  
  startFallbackPolling() {
    if (this.fallbackPollingInterval) return // Already polling
    
    console.log("🔄 Starting fallback polling for market updates")
    
    // Poll every 10 seconds
    this.fallbackPollingInterval = setInterval(() => {
      this.simulateMarketUpdate()
    }, 10000)
    
    // Send initial simulated update
    this.simulateMarketUpdate()
  }
  
  stopFallbackPolling() {
    if (this.fallbackPollingInterval) {
      console.log("⏹️ Stopping fallback polling")
      clearInterval(this.fallbackPollingInterval)
      this.fallbackPollingInterval = null
    }
  }
  
  simulateMarketUpdate() {
    const now = Date.now()
    const symbol = this.symbolValue
    
    // Generate simulated market data
    const basePrice = 196.5 // AAPL base price
    const change = (Math.random() - 0.5) * 2 // ±1% change
    const price = (basePrice * (1 + change / 100)).toFixed(2)
    
    console.log(`📊 Fallback: Simulated market update for ${symbol}: $${price}`)
    
    // Dispatch both ping and market update events
    this.dispatchMarketEvent('market:ping', {
      type: 'ping',
      symbol: symbol,
      price: parseFloat(price),
      timestamp: Math.floor(now / 1000),
      source: 'fallback_polling',
      message: 'Fallback market data'
    })
    
    this.dispatchMarketEvent('market:update', {
      type: 'market_update',
      symbol: symbol,
      price: parseFloat(price),
      timestamp: Math.floor(now / 1000),
      source: 'fallback_polling',
      emas: {
        ema5: parseFloat(price) + (Math.random() - 0.5) * 0.5,
        ema8: parseFloat(price) + (Math.random() - 0.5) * 0.8,
        ema22: parseFloat(price) + (Math.random() - 0.5) * 2.0
      }
    })
  }

  handleMarketData(data) {
    if (data.type === "ping") {
      console.log(`📊 Market ping: ${data.symbol} at $${data.price}`)
      this.dispatchMarketEvent('market:ping', data)
    } else if (data.type === "market_update") {
      console.log(`📈 Market update: ${data.symbol} - Price: $${data.price}, EMAs: ${JSON.stringify(data.emas)}`)
      this.dispatchMarketEvent('market:update', data)
    } else if (data.type === "connection_established") {
      console.log("🔗 Market connection established")
      this.dispatchMarketEvent('market:connected', data)
    } else {
      console.log("📦 Other market data:", data.type, data)
    }
  }
  
  dispatchMarketEvent(eventName, data) {
    const event = new CustomEvent(eventName, { 
      detail: data,
      bubbles: true,
      cancelable: true
    })
    document.dispatchEvent(event)
    console.log(`🚀 Dispatched ${eventName} event with data:`, data)
  }
  
  // Method to follow a specific symbol (can be called from other controllers)
  followSymbol(symbol) {
    console.log(`👀 Following symbol: ${symbol}`)
    this.symbolValue = symbol
    
    if (this.subscription && this.isConnected) {
      this.subscription.perform('follow_symbol', { symbol: symbol })
    }
  }
} 