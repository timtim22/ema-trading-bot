import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "flashMessage", "flashIcon", "flashText",
    "currentSymbols", "currentTimeframe", 
    "currentProfit", "currentLoss",
    "submitButton", "submitText"
  ]

  connect() {
    console.log("🔧 Bot Settings controller connected")
  }

  submitForm(event) {
    event.preventDefault()
    
    const form = event.target
    const formData = new FormData(form)
    
    // Note: Symbol validation is now handled server-side via TrackedSymbol model
    // No need for client-side symbol validation since symbols are managed separately

    // Show loading state
    this.setLoadingState(true)
    
    fetch(form.action, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.success) {
        this.showFlash('success', data.message)
        this.updateCurrentSettings(data.settings)
        
        // Redirect to dashboard after a short delay to show the success message
        setTimeout(() => {
          window.location.href = '/dashboard'
        }, 1500)
      } else {
        this.showFlash('error', data.message || 'Failed to update settings')
        if (data.errors) {
          console.error('Validation errors:', data.errors)
        }
      }
    })
    .catch(error => {
      console.error('Error updating settings:', error)
      this.showFlash('error', 'An error occurred while updating settings')
    })
    .finally(() => {
      this.setLoadingState(false)
    })
  }

  updateCurrentSettings(settings) {
    if (this.hasCurrentSymbolsTarget) {
      this.currentSymbolsTarget.textContent = settings.symbols
    }
    if (this.hasCurrentTimeframeTarget) {
      this.currentTimeframeTarget.textContent = settings.timeframe
    }
    if (this.hasCurrentProfitTarget) {
      this.currentProfitTarget.textContent = `${settings.profit_percentage}%`
    }
    if (this.hasCurrentLossTarget) {
      this.currentLossTarget.textContent = `${settings.loss_percentage}%`
    }
  }

  setLoadingState(loading) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = loading
    }
    
    if (this.hasSubmitTextTarget) {
      this.submitTextTarget.textContent = loading ? 'Saving...' : 'Save Settings'
    }
  }

  showFlash(type, message) {
    if (!this.hasFlashMessageTarget) return

    const flashDiv = this.flashMessageTarget
    const iconTarget = this.flashIconTarget
    const textTarget = this.flashTextTarget

    // Set message
    textTarget.textContent = message

    // Set icon and colors based on type
    if (type === 'success') {
      flashDiv.className = 'mb-6 rounded-md bg-green-50 p-4'
      iconTarget.setAttribute('class', 'h-5 w-5 text-green-400')
      iconTarget.innerHTML = `
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
      `
      textTarget.className = 'text-sm font-medium text-green-800'
    } else {
      flashDiv.className = 'mb-6 rounded-md bg-red-50 p-4'
      iconTarget.setAttribute('class', 'h-5 w-5 text-red-400')
      iconTarget.innerHTML = `
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
      `
      textTarget.className = 'text-sm font-medium text-red-800'
    }

    // Show the flash message
    flashDiv.classList.remove('hidden')

    // Auto-hide success messages after 5 seconds
    if (type === 'success') {
      setTimeout(() => {
        this.hideFlash()
      }, 5000)
    }
  }

  hideFlash() {
    if (this.hasFlashMessageTarget) {
      this.flashMessageTarget.classList.add('hidden')
    }
  }
} 