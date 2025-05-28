import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["statusBadge", "lastRun", "startButton", "stopButton", "startButtonText", "stopButtonText"]
  static values = { symbol: String }

  connect() {
    console.log("Bot status controller connected for symbol:", this.symbolValue)
  }

  async startBot() {
    console.log("Starting bot for symbol:", this.symbolValue)
    
    // Disable button and show loading state
    const button = this.startButtonTarget
    const buttonText = this.startButtonTextTarget
    
    button.disabled = true
    buttonText.textContent = "Starting..."
    
    try {
      const response = await fetch('/dashboard/bot/start', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          symbol: this.symbolValue
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Update UI to reflect running state
        this.updateStatusDisplay(true, data.status, data.last_run)
        this.showNotification(data.message, 'success')
        
        // Reload the page to update the button state
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        throw new Error(data.error || 'Failed to start bot')
      }
    } catch (error) {
      console.error('Error starting bot:', error)
      this.showNotification(error.message, 'error')
      
      // Re-enable button
      button.disabled = false
      buttonText.textContent = "Start Bot"
    }
  }

  async stopBot() {
    console.log("Stopping bot for symbol:", this.symbolValue)
    
    // Disable button and show loading state
    const button = this.stopButtonTarget
    const buttonText = this.stopButtonTextTarget
    
    button.disabled = true
    buttonText.textContent = "Stopping..."
    
    try {
      const response = await fetch('/dashboard/bot/stop', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          symbol: this.symbolValue
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Update UI to reflect stopped state
        this.updateStatusDisplay(false, data.status, data.last_run)
        this.showNotification(data.message, 'success')
        
        // Reload the page to update the button state
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        throw new Error(data.error || 'Failed to stop bot')
      }
    } catch (error) {
      console.error('Error stopping bot:', error)
      this.showNotification(error.message, 'error')
      
      // Re-enable button
      button.disabled = false
      buttonText.textContent = "Stop Bot"
    }
  }

  updateStatusDisplay(isRunning, statusText, lastRun) {
    // Update status badge
    const statusBadge = this.statusBadgeTarget
    const statusDot = statusBadge.querySelector('.w-2.h-2')
    
    if (isRunning) {
      statusBadge.className = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
      statusDot.className = "w-2 h-2 bg-green-400 rounded-full mr-1.5"
    } else {
      statusBadge.className = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
      statusDot.className = "w-2 h-2 bg-gray-400 rounded-full mr-1.5"
    }
    
    statusBadge.lastChild.textContent = statusText
    
    // Update last run time
    if (this.hasLastRunTarget) {
      this.lastRunTarget.textContent = lastRun
    }
  }

  showNotification(message, type = 'info') {
    // Create a simple notification
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-4 py-3 rounded-lg shadow-lg text-white ${
      type === 'success' ? 'bg-green-500' : 
      type === 'error' ? 'bg-red-500' : 'bg-blue-500'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Remove notification after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
} 