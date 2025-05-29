import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["symbolsList", "addForm", "symbolInput", "addButton", "message"]
  static values = { 
    createUrl: String,
    toggleUrl: String
  }

  connect() {
    console.log("🎯 Symbol manager controller connected")
    this.setupEventListeners()
  }

  disconnect() {
    this.removeEventListeners()
  }

  setupEventListeners() {
    // Listen for form submissions
    if (this.hasAddFormTarget) {
      this.addFormTarget.addEventListener('submit', this.handleAddSymbol.bind(this))
    }
  }

  removeEventListeners() {
    if (this.hasAddFormTarget) {
      this.addFormTarget.removeEventListener('submit', this.handleAddSymbol.bind(this))
    }
  }

  // Handle adding a new symbol
  async handleAddSymbol(event) {
    event.preventDefault()
    
    const formData = new FormData(event.target)
    const symbol = formData.get('tracked_symbol[symbol]')
    
    if (!symbol || symbol.trim() === '') {
      this.showMessage('Please enter a symbol', 'error')
      return
    }

    // Disable the form while processing
    this.setFormLoading(true)

    try {
      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      const data = await response.json()

      if (data.success) {
        this.addSymbolToList(data.tracked_symbol)
        this.clearForm()
        this.showMessage(data.message, 'success')
        this.updateAvailableSymbols()
      } else {
        this.showMessage(data.message || 'Failed to add symbol', 'error')
      }
    } catch (error) {
      console.error('Error adding symbol:', error)
      this.showMessage('Network error. Please try again.', 'error')
    } finally {
      this.setFormLoading(false)
    }
  }

  // Handle removing a symbol
  async removeSymbol(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const symbolId = button.dataset.symbolId
    const symbol = button.dataset.symbol
    
    if (!confirm(`Are you sure you want to remove ${symbol} from your tracking list?`)) {
      return
    }

    // Disable the button while processing
    button.disabled = true
    button.innerHTML = '<span class="animate-spin">⏳</span> Removing...'

    try {
      const response = await fetch(`/tracked_symbols/${symbolId}`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        this.removeSymbolFromList(symbolId)
        this.showMessage(data.message, 'success')
        this.updateAvailableSymbols()
      } else {
        this.showMessage(data.message || 'Failed to remove symbol', 'error')
        // Re-enable button on failure
        button.disabled = false
        button.innerHTML = '🗑️ Remove'
      }
    } catch (error) {
      console.error('Error removing symbol:', error)
      this.showMessage('Network error. Please try again.', 'error')
      // Re-enable button on failure
      button.disabled = false
      button.innerHTML = '🗑️ Remove'
    }
  }

  // Handle toggling symbol active status
  async toggleSymbol(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const symbolId = button.dataset.symbolId
    const symbol = button.dataset.symbol
    const isActive = button.dataset.active === 'true'
    
    // Disable the button while processing
    button.disabled = true
    const originalText = button.innerHTML
    button.innerHTML = '<span class="animate-spin">⏳</span> Updating...'

    try {
      const response = await fetch(`/tracked_symbols/${symbolId}/toggle`, {
        method: 'PATCH',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        this.updateSymbolStatus(symbolId, data.tracked_symbol)
        this.showMessage(data.message, 'success')
      } else {
        this.showMessage(data.message || 'Failed to update symbol', 'error')
      }
    } catch (error) {
      console.error('Error toggling symbol:', error)
      this.showMessage('Network error. Please try again.', 'error')
    } finally {
      // Re-enable button
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  // Add symbol to the UI list
  addSymbolToList(trackedSymbol) {
    if (!this.hasSymbolsListTarget) return

    const symbolElement = this.createSymbolElement(trackedSymbol)
    this.symbolsListTarget.appendChild(symbolElement)
    
    // Animate the new element
    setTimeout(() => {
      symbolElement.classList.remove('opacity-0', 'scale-95')
      symbolElement.classList.add('opacity-100', 'scale-100')
    }, 100)
  }

  // Remove symbol from the UI list
  removeSymbolFromList(symbolId) {
    const symbolElement = document.querySelector(`[data-symbol-id="${symbolId}"]`)
    if (symbolElement) {
      // Animate out
      symbolElement.classList.add('opacity-0', 'scale-95')
      setTimeout(() => {
        symbolElement.remove()
      }, 300)
    }
  }

  // Update symbol status in the UI
  updateSymbolStatus(symbolId, trackedSymbol) {
    const symbolElement = document.querySelector(`[data-symbol-id="${symbolId}"]`)
    if (!symbolElement) return

    const statusBadge = symbolElement.querySelector('.status-badge')
    const toggleButton = symbolElement.querySelector('.toggle-button')
    
    if (statusBadge) {
      statusBadge.textContent = trackedSymbol.active ? 'Active' : 'Inactive'
      statusBadge.className = `status-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
        trackedSymbol.active 
          ? 'bg-green-100 text-green-800' 
          : 'bg-gray-100 text-gray-800'
      }`
    }
    
    if (toggleButton) {
      toggleButton.dataset.active = trackedSymbol.active
      toggleButton.textContent = trackedSymbol.active ? '⏸️ Deactivate' : '▶️ Activate'
      toggleButton.className = `toggle-button px-3 py-1 text-xs font-medium rounded-md transition-colors ${
        trackedSymbol.active
          ? 'text-orange-700 bg-orange-100 hover:bg-orange-200'
          : 'text-green-700 bg-green-100 hover:bg-green-200'
      }`
    }
  }

  // Create HTML element for a tracked symbol
  createSymbolElement(trackedSymbol) {
    const div = document.createElement('div')
    div.className = 'opacity-0 scale-95 transform transition-all duration-300 bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md'
    div.dataset.symbolId = trackedSymbol.id
    
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <div class="flex-shrink-0">
            <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <span class="text-sm font-bold text-blue-600">${trackedSymbol.symbol}</span>
            </div>
          </div>
          <div>
            <h3 class="text-sm font-medium text-gray-900">${trackedSymbol.symbol}</h3>
            <span class="status-badge inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
              trackedSymbol.active 
                ? 'bg-green-100 text-green-800' 
                : 'bg-gray-100 text-gray-800'
            }">
              ${trackedSymbol.active ? 'Active' : 'Inactive'}
            </span>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          <button 
            class="toggle-button px-3 py-1 text-xs font-medium rounded-md transition-colors ${
              trackedSymbol.active
                ? 'text-orange-700 bg-orange-100 hover:bg-orange-200'
                : 'text-green-700 bg-green-100 hover:bg-green-200'
            }"
            data-action="click->symbol-manager#toggleSymbol"
            data-symbol-id="${trackedSymbol.id}"
            data-symbol="${trackedSymbol.symbol}"
            data-active="${trackedSymbol.active}">
            ${trackedSymbol.active ? '⏸️ Deactivate' : '▶️ Activate'}
          </button>
          <button 
            class="px-3 py-1 text-xs font-medium text-red-700 bg-red-100 hover:bg-red-200 rounded-md transition-colors"
            data-action="click->symbol-manager#removeSymbol"
            data-symbol-id="${trackedSymbol.id}"
            data-symbol="${trackedSymbol.symbol}">
            🗑️ Remove
          </button>
        </div>
      </div>
    `
    
    return div
  }

  // Clear the add form
  clearForm() {
    if (this.hasSymbolInputTarget) {
      this.symbolInputTarget.value = ''
    }
  }

  // Set form loading state
  setFormLoading(loading) {
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = loading
      this.addButtonTarget.innerHTML = loading 
        ? '<span class="animate-spin">⏳</span> Adding...' 
        : '➕ Add Symbol'
    }
    
    if (this.hasSymbolInputTarget) {
      this.symbolInputTarget.disabled = loading
    }
  }

  // Show message to user
  showMessage(message, type = 'info') {
    if (!this.hasMessageTarget) return

    const bgColor = type === 'success' ? 'bg-green-50 border-green-200' : 
                   type === 'error' ? 'bg-red-50 border-red-200' : 
                   'bg-blue-50 border-blue-200'
    
    const textColor = type === 'success' ? 'text-green-800' : 
                     type === 'error' ? 'text-red-800' : 
                     'text-blue-800'

    this.messageTarget.className = `p-4 rounded-md border ${bgColor} ${textColor} transition-all duration-300`
    this.messageTarget.textContent = message
    this.messageTarget.classList.remove('hidden')

    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.messageTarget.classList.add('hidden')
    }, 5000)
  }

  // Update available symbols dropdown/list
  updateAvailableSymbols() {
    // This could be enhanced to dynamically update available symbols
    // For now, we'll just trigger a page refresh or update via Turbo
    console.log("📊 Available symbols updated")
  }
} 