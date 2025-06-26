import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "refreshButton", 
    "refreshText", 
    "lastUpdated",
    "portfolioValue",
    "buyingPower", 
    "cash", 
    "equity"
  ]
  
  connect() {
    console.log("Account controller connected")
    
    // Set up auto-refresh every 30 seconds
    this.autoRefreshInterval = setInterval(() => {
      this.refreshAccount()
    }, 30000)
  }
  
  disconnect() {
    if (this.autoRefreshInterval) {
      clearInterval(this.autoRefreshInterval)
    }
  }
  
  async refreshAccount() {
    console.log("Refreshing account data...")
    
    // Update button state
    this.setRefreshingState(true)
    
    try {
      const response = await fetch('/account/refresh', {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (data.success) {
        console.log("Account data refreshed successfully")
        
        // Update the displayed values
        this.updateAccountValues(data)
        
        // Update last updated time
        if (this.hasLastUpdatedTarget) {
          this.lastUpdatedTarget.textContent = data.last_updated
        }
        
        // Show success notification
        this.showNotification("Account data refreshed", "success")
      } else {
        console.error("Failed to refresh account data:", data.error)
        this.showNotification(`Error: ${data.error}`, "error")
      }
    } catch (error) {
      console.error("Error refreshing account data:", error)
      this.showNotification("Failed to refresh account data", "error")
    } finally {
      this.setRefreshingState(false)
    }
  }
  
  updateAccountValues(data) {
    const accountInfo = data.account_info
    const performanceMetrics = data.performance_metrics
    
    if (!accountInfo) return
    
    // Update portfolio value
    if (this.hasPortfolioValueTarget) {
      this.portfolioValueTarget.textContent = `$${this.formatNumber(accountInfo.portfolio_value)}`
    }
    
    // Update buying power
    if (this.hasBuyingPowerTarget) {
      this.buyingPowerTarget.textContent = `$${this.formatNumber(accountInfo.buying_power)}`
    }
    
    // Update cash
    if (this.hasCashTarget) {
      this.cashTarget.textContent = `$${this.formatNumber(accountInfo.cash)}`
    }
    
    // Update equity
    if (this.hasEquityTarget) {
      this.equityTarget.textContent = `$${this.formatNumber(accountInfo.equity)}`
    }
    
    console.log("Account values updated:", {
      portfolio_value: accountInfo.portfolio_value,
      buying_power: accountInfo.buying_power,
      cash: accountInfo.cash,
      equity: accountInfo.equity
    })
  }
  
  setRefreshingState(isRefreshing) {
    if (!this.hasRefreshButtonTarget || !this.hasRefreshTextTarget) return
    
    this.refreshButtonTarget.disabled = isRefreshing
    
    if (isRefreshing) {
      this.refreshTextTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Refreshing...
      `
    } else {
      this.refreshTextTarget.textContent = "Refresh"
    }
  }
  
  formatNumber(value) {
    if (typeof value !== 'number') return '0.00'
    
    return new Intl.NumberFormat('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value)
  }
  
  showNotification(message, type = 'info') {
    // Prevent notification spam
    const now = Date.now()
    this.lastNotification = this.lastNotification || 0
    if (now - this.lastNotification < 1000) return // Reduced to 1 second
    this.lastNotification = now
    
    // Create or get notification container
    let container = document.getElementById('notification-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'notification-container'
      container.className = 'fixed top-20 right-4 z-50 space-y-2 pointer-events-none'
      container.style.maxWidth = '384px' // max-w-sm equivalent
      document.body.appendChild(container)
    }
    
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden transform transition-all duration-300 ease-in-out translate-x-full opacity-0`
    
    const iconColor = type === 'success' ? 'text-green-400' : type === 'error' ? 'text-red-400' : 'text-blue-400'
    const textColor = type === 'success' ? 'text-green-800' : type === 'error' ? 'text-red-800' : 'text-blue-800'
    const bgColor = type === 'success' ? 'bg-green-50' : type === 'error' ? 'bg-red-50' : 'bg-blue-50'
    
    notification.innerHTML = `
      <div class="p-4 ${bgColor}">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 ${iconColor}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              ${type === 'success' ? 
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />' :
                type === 'error' ?
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />' :
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
              }
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium ${textColor}">${message}</p>
          </div>
          <div class="ml-4 flex-shrink-0">
            <button class="inline-flex rounded-md ${bgColor} text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-green-50 focus:ring-green-600" onclick="this.closest('.notification-item').remove()">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    // Add a class for easier removal
    notification.classList.add('notification-item')
    
    // Add to container
    container.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
      notification.classList.add('translate-x-0', 'opacity-100')
    }, 100)
    
    // Auto remove after 4 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.classList.add('translate-x-full', 'opacity-0')
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove()
            
            // Clean up container if empty
            if (container.children.length === 0) {
              container.remove()
            }
          }
        }, 300)
      }
    }, 4000)
  }
} 