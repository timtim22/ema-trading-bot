import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "price", "lastUpdate", "dataSource"]
  static values = { 
    symbol: String,
    pollingInterval: Number,
    pollingEnabled: Boolean
  }
  
  connect() {
    // Default values
    this.symbolValue = this.symbolValue || "AAPL"
    this.pollingIntervalValue = this.pollingIntervalValue || 10
    this.pollingEnabledValue = this.pollingEnabledValue || false
    
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Connecting..."
      this.statusTarget.classList.remove("bg-green-100", "text-green-800")
      this.statusTarget.classList.add("bg-yellow-100", "text-yellow-800")
    }
    
    // Bind event handlers
    this.pingHandler = this.handlePing.bind(this)
    this.updateHandler = this.handleMarketUpdate.bind(this)
    this.connectedHandler = this.handleConnected.bind(this)
    this.disconnectedHandler = this.handleDisconnected.bind(this)
    
    document.addEventListener('market:ping', this.pingHandler)
    document.addEventListener('market:update', this.updateHandler)
    document.addEventListener('market:connected', this.connectedHandler)
    document.addEventListener('market:disconnected', this.disconnectedHandler)
    
    // Start polling if WebSockets are unavailable
    if (this.pollingEnabledValue) {
      this.startPolling()
    }
  }
  
  disconnect() {
    // Clean up event listeners
    document.removeEventListener('market:ping', this.pingHandler)
    document.removeEventListener('market:update', this.updateHandler)
    document.removeEventListener('market:connected', this.connectedHandler)
    document.removeEventListener('market:disconnected', this.disconnectedHandler)
    
    // Clear polling if active
    this.stopPolling()
  }
  
  handleConnected(event) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Connected"
      this.statusTarget.classList.remove("bg-yellow-100", "text-yellow-800")
      this.statusTarget.classList.remove("bg-red-100", "text-red-800")
      this.statusTarget.classList.add("bg-green-100", "text-green-800")
    }
  }
  
  handleDisconnected(event) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Disconnected"
      this.statusTarget.classList.remove("bg-green-100", "text-green-800")
      this.statusTarget.classList.remove("bg-yellow-100", "text-yellow-800")
      this.statusTarget.classList.add("bg-red-100", "text-red-800")
    }
  }
  
  handlePing(event) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Connected"
      this.statusTarget.classList.remove("bg-yellow-100", "text-yellow-800")
      this.statusTarget.classList.remove("bg-red-100", "text-red-800")
      this.statusTarget.classList.add("bg-green-100", "text-green-800")
    }
    
    if (this.hasLastUpdateTarget) {
      const date = new Date(event.detail.timestamp * 1000)
      const timestamp = date.toLocaleTimeString('en-US', {
        timeZone: 'America/New_York',
        hour12: true,
        hour: 'numeric',
        minute: '2-digit',
        second: '2-digit'
      })
      
      // Automatically detect EDT vs EST based on daylight saving time
      const timezoneName = date.toLocaleDateString('en-US', {
        timeZone: 'America/New_York',
        timeZoneName: 'short'
      }).split(', ')[1]
      
      this.lastUpdateTarget.textContent = `${timestamp} ${timezoneName} (${event.detail.symbol}) - $${event.detail.price}`
    }
    
    // Update data source indicator
    if (this.hasDataSourceTarget && event.detail.source) {
      this.updateDataSourceIndicator(event.detail.source)
    }
    
    // Update price if this ping is for our current symbol
    if (this.hasPriceTarget && event.detail.symbol === this.symbolValue && event.detail.price) {
      this.priceTarget.textContent = `$${event.detail.price}`
    }
  }
  
  handleMarketUpdate(event) {
    // Update UI with market data
    if (this.hasPriceTarget && event.detail.price) {
      this.priceTarget.textContent = `$${event.detail.price}`
    }
    
    // Update data source indicator
    if (this.hasDataSourceTarget && event.detail.source) {
      this.updateDataSourceIndicator(event.detail.source)
    }
  }
  
  updateDataSourceIndicator(source) {
    if (!this.hasDataSourceTarget) return
    
    // Remove existing classes
    this.dataSourceTarget.classList.remove(
      "bg-blue-100", "text-blue-800",
      "bg-green-100", "text-green-800", 
      "bg-yellow-100", "text-yellow-800"
    )
    
    // Update based on source
    if (source === 'alpaca') {
      this.dataSourceTarget.textContent = "Alpaca API"
      this.dataSourceTarget.classList.add("bg-green-100", "text-green-800")
    } else if (source === 'simulated') {
      this.dataSourceTarget.textContent = "Simulated"
      this.dataSourceTarget.classList.add("bg-yellow-100", "text-yellow-800")
    } else {
      this.dataSourceTarget.textContent = "Unknown"
      this.dataSourceTarget.classList.add("bg-blue-100", "text-blue-800")
    }
  }
  
  // Manual follow method that can be triggered from UI
  followSymbol(event) {
    const symbol = event.currentTarget.dataset.symbol || this.symbolValue
    
    // Use the global marketChannel
    if (window.marketChannel) {
      window.marketChannel.followSymbol(symbol)
      
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = `Following ${symbol}...`
      }
    }
  }
  
  // Polling fallback implementation
  startPolling() {
    this.pollingTimer = setInterval(() => {
      this.pollMarketData()
    }, this.pollingIntervalValue * 1000)
  }
  
  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
    }
  }
  
  pollMarketData() {
    // Simulate a ping event for testing
    document.dispatchEvent(new CustomEvent('market:ping', { 
      detail: { 
        type: 'ping', 
        timestamp: Math.floor(Date.now() / 1000),
        symbol: this.symbolValue,
        price: (Math.random() * 200 + 100).toFixed(2),
        message: 'Poll ping (fallback)'
      } 
    }))
  }
} 