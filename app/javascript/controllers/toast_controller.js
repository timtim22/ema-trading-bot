import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    console.log("Toast controller connected")
    
    // Make Toast system globally available
    window.Toast = this
    
    // Initialize session warnings tracking
    this.sessionWarnings = new Set()
    const storedWarnings = sessionStorage.getItem('shownWarnings')
    if (storedWarnings) {
      try {
        const warnings = JSON.parse(storedWarnings)
        warnings.forEach(warning => this.sessionWarnings.add(warning))
      } catch (e) {
        console.warn('Failed to parse stored warnings:', e)
      }
    }
    
    this.createContainer()
    
    // Convert existing flash messages to toast notifications
    this.convertFlashMessages()
    
    // Listen for toast events
    window.addEventListener('showToast', this.handleToastEvent.bind(this))
    window.addEventListener('notifications:error', this.handleError.bind(this))
    window.addEventListener('notifications:warning', this.handleWarning.bind(this))
    window.addEventListener('notifications:success', this.handleSuccess.bind(this))
    window.addEventListener('notifications:info', this.handleInfo.bind(this))
  }
  
  disconnect() {
    window.removeEventListener('showToast', this.handleToastEvent.bind(this))
    window.removeEventListener('notifications:error', this.handleError.bind(this))
    window.removeEventListener('notifications:warning', this.handleWarning.bind(this))
    window.removeEventListener('notifications:success', this.handleSuccess.bind(this))
    window.removeEventListener('notifications:info', this.handleInfo.bind(this))
  }
  
  createContainer() {
    // Remove any existing containers from other controllers
    const existingContainers = document.querySelectorAll('#notification-container, #toast-container')
    existingContainers.forEach(container => container.remove())
    
    // Create new container positioned below navbar
    const container = document.createElement('div')
    container.id = 'toast-container'
    container.className = 'fixed top-20 right-4 z-50 space-y-2 pointer-events-none max-w-sm'
    document.body.appendChild(container)
    this.container = container
  }
  
  handleToastEvent(event) {
    const { message, type, persistent, warningKey } = event.detail
    this.show(message, type, persistent, warningKey)
  }
  
  handleError(event) {
    this.show(event.detail.message, 'error', event.detail.persistent)
  }
  
  handleWarning(event) {
    this.show(event.detail.message, 'warning', event.detail.persistent, event.detail.warningKey)
  }
  
  handleSuccess(event) {
    this.show(event.detail.message, 'success', event.detail.persistent)
  }
  
  handleInfo(event) {
    this.show(event.detail.message, 'info', event.detail.persistent)
  }
  
  show(message, type = 'info', persistent = false, warningKey = null) {
    // For warnings, check if we've already shown this warning in this session
    if (type === 'warning' && warningKey) {
      if (this.sessionWarnings.has(warningKey)) {
        console.log(`Session warning '${warningKey}' already shown, skipping`)
        return // Don't show the same warning twice in one session
      }
      this.sessionWarnings.add(warningKey)
      sessionStorage.setItem('shownWarnings', JSON.stringify([...this.sessionWarnings]))
      console.log(`Session warning '${warningKey}' added to session storage`)
    }
    
    // Prevent notification spam
    const now = Date.now()
    this.lastNotification = this.lastNotification || 0
    if (now - this.lastNotification < 500) return
    this.lastNotification = now
    
    if (!this.container) {
      this.createContainer()
    }
    
    // Create notification element with initial off-screen positioning
    const notification = document.createElement('div')
    notification.className = `shadow-lg rounded-lg ring-1 ring-black ring-opacity-5 overflow-hidden backdrop-blur-sm transform translate-x-full opacity-0 transition-all duration-300 ease-in-out pointer-events-none`
    
    const config = this.getTypeConfig(type)
    
    notification.innerHTML = `
      <div class="p-4 ${config.bgColor}">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 ${config.iconColor}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              ${config.icon}
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium ${config.textColor}">${message}</p>
          </div>
          <div class="ml-4 flex-shrink-0">
            <button class="inline-flex rounded-md text-white text-opacity-60 hover:text-white focus:outline-none focus:text-white transition-colors duration-200" 
                    onclick="this.closest('.toast-notification').remove()">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    // Add identifying class
    notification.classList.add('toast-notification')
    
    // Add to container (element starts off-screen with CSS classes)
    this.container.appendChild(notification)
    
    // Force a reflow then animate in by removing off-screen classes
    notification.offsetHeight
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0', 'pointer-events-none')
      notification.classList.add('translate-x-0', 'opacity-100', 'pointer-events-auto')
    }, 10)
    
    // Auto-remove after delay (unless persistent)
    if (!persistent) {
      const duration = type === 'error' ? 8000 : type === 'warning' ? 6000 : 4000
      setTimeout(() => {
        this.removeNotification(notification)
      }, duration)
    }
  }
  
  removeNotification(notification) {
    if (notification && notification.parentElement) {
      notification.classList.remove('translate-x-0', 'opacity-100')
      notification.classList.add('translate-x-full', 'opacity-0')
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 300)
    }
  }
  
  getTypeConfig(type) {
    const configs = {
      success: {
        bgColor: 'bg-gradient-to-r from-purple-900 to-purple-800 border border-purple-600',
        textColor: 'text-white',
        iconColor: 'text-green-400',
        color: 'purple',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />'
      },
      error: {
        bgColor: 'bg-gradient-to-r from-red-900 to-red-800 border border-red-600',
        textColor: 'text-white',
        iconColor: 'text-red-400',
        color: 'red',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
      },
      warning: {
        bgColor: 'bg-gradient-to-r from-yellow-900 to-yellow-800 border border-yellow-600',
        textColor: 'text-white',
        iconColor: 'text-yellow-400',
        color: 'yellow',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 16.5c-.77.833.192 2.5 1.732 2.5z" />'
      },
      info: {
        bgColor: 'bg-gradient-to-r from-blue-900 to-blue-800 border border-blue-600',
        textColor: 'text-white',
        iconColor: 'text-blue-400',
        color: 'blue',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
      }
    }
    
    return configs[type] || configs.info
  }
  
  // Public API methods for other controllers
  success(message, persistent = false) {
    this.show(message, 'success', persistent)
  }
  
  error(message, persistent = false) {
    this.show(message, 'error', persistent)
  }
  
  warning(message, persistent = false, warningKey = null) {
    this.show(message, 'warning', persistent, warningKey)
  }
  
  info(message, persistent = false) {
    this.show(message, 'info', persistent)
  }
  
  // Clear all notifications
  clearAll() {
    const notifications = this.container?.querySelectorAll('.toast-notification')
    notifications?.forEach(notification => this.removeNotification(notification))
  }
  
  convertFlashMessages() {
    // Look for notice flash messages and convert them to success toasts
    const noticeElements = document.querySelectorAll('[class*="bg-gradient-to-r from-purple-900"]')
    noticeElements.forEach(element => {
      const messageElement = element.querySelector('p')
      if (messageElement) {
        const message = messageElement.textContent.trim()
        if (message) {
          // Hide the original flash immediately
          element.parentElement.style.display = 'none'
          // Show as toast notification
          this.success(message)
        }
      }
    })
    
    // Look for alert flash messages and convert them to error toasts
    const alertElements = document.querySelectorAll('[class*="bg-gradient-to-r from-red-900"]')
    alertElements.forEach(element => {
      const messageElement = element.querySelector('p')
      if (messageElement) {
        const message = messageElement.textContent.trim()
        if (message) {
          // Hide the original flash immediately
          element.parentElement.style.display = 'none'
          // Show as toast notification
          this.error(message)
        }
      }
    })
  }
}

// Global session warnings management
window.ToastSessionWarnings = new Set()
const storedWarnings = sessionStorage.getItem('shownWarnings')
if (storedWarnings) {
  try {
    const warnings = JSON.parse(storedWarnings)
    warnings.forEach(warning => window.ToastSessionWarnings.add(warning))
  } catch (e) {
    console.warn('Failed to parse stored warnings:', e)
  }
}

// Global helper function for easy access
window.Toast = {
  show: (message, type = 'info', persistent = false, warningKey = null) => {
    // Handle session warnings at the global level
    if (type === 'warning' && warningKey) {
      if (window.ToastSessionWarnings.has(warningKey)) {
        console.log(`Global session warning '${warningKey}' already shown, skipping`)
        return // Don't show the same warning twice in one session
      }
      window.ToastSessionWarnings.add(warningKey)
      sessionStorage.setItem('shownWarnings', JSON.stringify([...window.ToastSessionWarnings]))
      console.log(`Global session warning '${warningKey}' added to session storage`)
    }
    
    window.dispatchEvent(new CustomEvent('showToast', {
      detail: { message, type, persistent, warningKey }
    }))
  },
  success: (message, persistent = false) => {
    window.Toast.show(message, 'success', persistent)
  },
  error: (message, persistent = false) => {
    window.Toast.show(message, 'error', persistent)
  },
  warning: (message, persistent = false, warningKey = null) => {
    window.Toast.show(message, 'warning', persistent, warningKey)
  },
  info: (message, persistent = false) => {
    window.Toast.show(message, 'info', persistent)
  },
  // Method to clear session warnings for testing
  clearSessionWarnings: () => {
    window.ToastSessionWarnings.clear()
    sessionStorage.removeItem('shownWarnings')
    console.log('Session warnings cleared')
  }
} 