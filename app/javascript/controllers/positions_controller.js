import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["currentPrice", "pnl", "closeButtonText"]
  static values = { symbol: String }
  
  connect() {
    console.log("🔌 Positions controller connected")
    console.log("🔍 Symbol value:", this.symbolValue)
    console.log("🎯 Found targets:", {
      currentPrice: this.currentPriceTargets.length,
      pnl: this.pnlTargets.length
    })
    
    // Listen for market update events dispatched by market channel controller
    this.marketUpdateHandler = this.handleMarketUpdate.bind(this)
    document.addEventListener('market:update', this.marketUpdateHandler)
  }
  
  disconnect() {
    console.log("🔌 Positions controller disconnecting")
    document.removeEventListener('market:update', this.marketUpdateHandler)
  }
  
  handleMarketUpdate(event) {
    console.log("📨 Positions controller received market update:", event.detail)
    this.updatePositionPrices(event.detail)
  }
  
  updatePositionPrices(data) {
    console.log("🔄 Processing received data:", data)
    
    // Only process market_update events with price data
    if (data.type !== 'market_update' || !data.price || !data.symbol) {
      console.log("⏭️ Skipping data - not a market_update or missing price/symbol")
      return
    }
    
    console.log(`💰 Updating positions for ${data.symbol} with price $${data.price}`)
    
    // Update current prices for matching symbols
    this.currentPriceTargets.forEach(target => {
      const symbol = target.dataset.symbol
      console.log(`🔍 Checking target symbol: ${symbol} vs ${data.symbol}`)
      if (symbol === data.symbol) {
        target.innerHTML = `$${parseFloat(data.price).toFixed(2)}`
        console.log(`✅ Updated ${symbol} price display to $${data.price}`)
      }
    })
    
    // Update P/L for all positions of this symbol
    this.updatePositionsForSymbol(data.symbol, data.price)
  }
  
  updatePositionsForSymbol(symbol, currentPrice) {
    // Find all position rows for this symbol
    const positionRows = this.element.querySelectorAll(`tr[data-position-id]`)
    
    positionRows.forEach(row => {
      const symbolCell = row.querySelector('td:first-child')
      if (symbolCell && symbolCell.textContent.trim() === symbol) {
        // Update current price display
        const currentPriceCell = row.querySelector('[data-positions-target="currentPrice"]')
        if (currentPriceCell) {
          currentPriceCell.innerHTML = `$${parseFloat(currentPrice).toFixed(2)}`
        }
        
        // Update P/L calculation and display
        this.updatePositionPnLDisplay(row, currentPrice)
      }
    })
  }
  
  updatePositionPnLDisplay(row, currentPrice) {
    try {
      // Get entry price from the row
      const entryPriceCell = row.querySelector('td:nth-child(2)')
      if (!entryPriceCell) return
      
      const entryPriceText = entryPriceCell.textContent.replace('$', '').replace(',', '')
      const entryPrice = parseFloat(entryPriceText)
      
      if (isNaN(entryPrice) || entryPrice === 0) return
      
      // Calculate P/L percentage
      const pnlPercentage = ((currentPrice - entryPrice) / entryPrice * 100)
      const formattedPnl = `${pnlPercentage >= 0 ? '+' : ''}${pnlPercentage.toFixed(2)}%`
      
      // Update P/L display
      const pnlCell = row.querySelector('[data-positions-target="pnl"]')
      if (pnlCell) {
        pnlCell.textContent = formattedPnl
        
        // Update color class
        pnlCell.className = pnlCell.className.replace(/text-(green|red|gray)-600/g, '')
        if (pnlPercentage > 0) {
          pnlCell.classList.add('text-green-600')
        } else if (pnlPercentage < 0) {
          pnlCell.classList.add('text-red-600')
        } else {
          pnlCell.classList.add('text-gray-600')
        }
        
        console.log(`Updated ${row.querySelector('td:first-child').textContent} P/L to ${formattedPnl}`)
      }
    } catch (error) {
      console.error('Error updating P/L display:', error)
    }
  }
  
  async updatePositionPnL(positionId, currentPrice) {
    try {
      const response = await fetch(`/positions/${positionId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const position = await response.json()
        
        // Calculate new P/L based on current price
        const entryPrice = parseFloat(position.entry_price)
        const pnlPercentage = ((currentPrice - entryPrice) / entryPrice * 100)
        const formattedPnl = `${pnlPercentage >= 0 ? '+' : ''}${pnlPercentage.toFixed(2)}%`
        
        // Update P/L display
        const positionRow = this.element.querySelector(`tr[data-position-id="${positionId}"]`)
        if (positionRow) {
          const pnlCell = positionRow.querySelector('[data-positions-target="pnl"]')
          if (pnlCell) {
            pnlCell.textContent = formattedPnl
            
            // Update color class
            pnlCell.className = pnlCell.className.replace(/text-(green|red|gray)-600/g, '')
            if (pnlPercentage > 0) {
              pnlCell.classList.add('text-green-600')
            } else if (pnlPercentage < 0) {
              pnlCell.classList.add('text-red-600')
            } else {
              pnlCell.classList.add('text-gray-600')
            }
          }
        }
      }
    } catch (error) {
      console.error('Error updating position P/L:', error)
    }
  }
  
  async closePosition(event) {
    const button = event.currentTarget
    const positionId = button.dataset.positionId
    const buttonText = button.querySelector('[data-positions-target="closeButtonText"]')
    
    if (!positionId) {
      console.error('No position ID found')
      return
    }
    
    // Disable button and show loading state
    button.disabled = true
    if (buttonText) {
      buttonText.textContent = 'Closing...'
    }
    
    try {
      const response = await fetch(`/positions/${positionId}/close_manually`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (response.ok && data.success) {
        // Show success notification
        this.showNotification(data.message, 'success')
        
        // Remove the position row from the table
        const positionRow = this.element.querySelector(`tr[data-position-id="${positionId}"]`)
        if (positionRow) {
          positionRow.style.transition = 'opacity 0.3s ease-out'
          positionRow.style.opacity = '0'
          setTimeout(() => {
            positionRow.remove()
            
            // Check if table is now empty and show empty state
            const remainingRows = this.element.querySelectorAll('tr[data-position-id]')
            if (remainingRows.length === 0) {
              this.showEmptyState()
            }
          }, 300)
        }
      } else {
        throw new Error(data.error || 'Failed to close position')
      }
    } catch (error) {
      console.error('Error closing position:', error)
      this.showNotification(`Error: ${error.message}`, 'error')
      
      // Re-enable button
      button.disabled = false
      if (buttonText) {
        buttonText.textContent = 'Close'
      }
    }
  }
  
  showEmptyState() {
    const tbody = this.element
    tbody.innerHTML = `
      <tr>
        <td colspan="7" class="px-4 sm:px-6 py-8 text-center">
          <div class="text-gray-500">
            <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
              <path d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A10.003 10.003 0 0124 26c4.21 0 7.813 2.602 9.288 6.286M30 14a6 6 0 11-12 0 6 6 0 0112 0zm12 6a4 4 0 11-8 0 4 4 0 018 0zm-28 0a4 4 0 11-8 0 4 4 0 018 0z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No active positions</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by configuring your trading bot.</p>
            <div class="mt-4">
              <button class="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 shadow-sm transition-all duration-200 hover:shadow-md">
                <svg class="-ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                </svg>
                Create Test Position
              </button>
            </div>
          </div>
        </td>
      </tr>
    `
  }
  
  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden transform transition-all duration-300 ease-in-out translate-x-full`
    
    const bgColor = type === 'success' ? 'bg-green-50' : type === 'error' ? 'bg-red-50' : 'bg-blue-50'
    const textColor = type === 'success' ? 'text-green-800' : type === 'error' ? 'text-red-800' : 'text-blue-800'
    const iconColor = type === 'success' ? 'text-green-400' : type === 'error' ? 'text-red-400' : 'text-blue-400'
    
    notification.innerHTML = `
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 ${iconColor}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              ${type === 'success' ? 
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />' :
                type === 'error' ?
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />' :
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
              }
            </svg>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium ${textColor}">${message}</p>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full')
    }, 100)
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification)
        }
      }, 300)
    }, 5000)
  }
} 