import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { symbol: String }
  
  connect() {
    console.log("🔌 Market channel controller connected")
    this.symbolValue = this.symbolValue || "AAPL"
    this.setupActionCable()
  }
  
  disconnect() {
    console.log("🔌 Market channel controller disconnected")
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
  
  setupActionCable() {
    console.log("📡 Setting up ActionCable for market data...")
    
    this.consumer = createConsumer()
    
    // Subscribe to the market channel
    this.subscription = this.consumer.subscriptions.create(
      "MarketChannel",
      {
        connected: () => {
          console.log("✅ Connected to MarketChannel")
          this.dispatchMarketEvent('market:connected', { message: 'Connected to market updates' })
        },
        
        disconnected: () => {
          console.log("❌ Disconnected from MarketChannel")
          this.dispatchMarketEvent('market:disconnected', { message: 'Disconnected from market updates' })
        },
        
        rejected: () => {
          console.log("🚫 MarketChannel subscription rejected")
        },
        
        received: (data) => {
          console.log("📨 Received market data:", data)
          this.handleMarketData(data)
        }
      }
    )
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
    
    if (this.subscription) {
      this.subscription.perform('follow_symbol', { symbol: symbol })
    }
  }
} 