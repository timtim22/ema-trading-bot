import consumer from "./consumer"

// Configuration - can be adjusted as needed
const MARKET_CONFIG = {
  ping_interval: 10, // seconds
  log_pings: false,  // disabled for production
  reconnect_attempts: 3,
  update_chart: true
}

// Create the channel consumer
const marketChannel = consumer.subscriptions.create("MarketChannel", {
  // Called when the subscription is ready for use on the server
  connected() {
    this.followSymbol("AAPL")  // Default to following AAPL
    
    // Dispatch connection event
    document.dispatchEvent(new CustomEvent('market:connected', { 
      detail: { type: 'connection_established', message: 'Connected to market updates' }
    }))
  },

  // Called when the WebSocket connection is closed
  disconnected() {
    // Dispatch disconnection event
    document.dispatchEvent(new CustomEvent('market:disconnected', { 
      detail: { type: 'disconnected' }
    }))
  },

  // Called when there's incoming data on the websocket for this channel
  received(data) {
    // Handle different types of data
    if (data.type === 'ping') {
      if (MARKET_CONFIG.log_pings) {
        console.log(`Market ping: ${data.symbol} - $${data.price}`)
      }
      
      // Dispatch a custom event for the market ping
      document.dispatchEvent(new CustomEvent('market:ping', { 
        detail: data 
      }))
    } else if (data.type === 'connection_established') {
      document.dispatchEvent(new CustomEvent('market:connected', { 
        detail: data 
      }))
    } else if (data.type === 'following_symbol') {
      document.dispatchEvent(new CustomEvent('market:following', { 
        detail: data 
      }))
    } else {
      // Dispatch a custom event for other market data
      document.dispatchEvent(new CustomEvent('market:update', { 
        detail: data 
      }))
    }
  },
  
  // Custom method to follow a specific symbol
  followSymbol(symbol) {
    this.perform('follow', { symbol: symbol })
  }
})

// Make available globally for debugging
window.marketChannel = marketChannel

export default marketChannel
