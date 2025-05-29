import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "autoRefreshButton",
    "autoRefreshText", 
    "refreshButton",
    "refreshText",
    "filterForm",
    "activityList",
    "activityCount",
    "statusIndicator",
    "totalCount",
    "errorCount", 
    "signalCount",
    "orderCount"
  ]
  
  connect() {
    console.log("Activity logs controller connected")
    console.log("Available targets:", this.targets)
    console.log("Has activityList target:", this.hasActivityListTarget)
    
    // Debug: log all elements with the target attribute
    const activityListElements = document.querySelectorAll('[data-activity-logs-target="activityList"]')
    console.log("Found activityList elements:", activityListElements.length, activityListElements)
    
    this.autoRefreshEnabled = false
    this.autoRefreshInterval = null
    this.lastActivityId = this.getLastActivityId()
    
    // Check for new activities every 5 seconds when auto-refresh is enabled
    this.streamInterval = setInterval(() => {
      if (this.autoRefreshEnabled) {
        this.streamNewActivities()
      }
    }, 5000)
  }
  
  disconnect() {
    if (this.autoRefreshInterval) {
      clearInterval(this.autoRefreshInterval)
    }
    if (this.streamInterval) {
      clearInterval(this.streamInterval)
    }
  }
  
  toggleAutoRefresh() {
    this.autoRefreshEnabled = !this.autoRefreshEnabled
    
    if (this.autoRefreshEnabled) {
      this.autoRefreshTextTarget.textContent = "Auto Refresh: ON"
      this.autoRefreshButtonTarget.classList.remove("text-gray-700", "bg-white")
      this.autoRefreshButtonTarget.classList.add("text-green-700", "bg-green-50", "border-green-300")
      
      // Update status indicator
      this.statusIndicatorTarget.innerHTML = `
        <div class="w-2 h-2 bg-green-400 rounded-full mr-1.5 animate-pulse"></div>
        Live (Auto)
      `
      this.statusIndicatorTarget.className = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
      
      console.log("Auto-refresh enabled")
    } else {
      this.autoRefreshTextTarget.textContent = "Auto Refresh: OFF"
      this.autoRefreshButtonTarget.classList.remove("text-green-700", "bg-green-50", "border-green-300")
      this.autoRefreshButtonTarget.classList.add("text-gray-700", "bg-white")
      
      // Update status indicator
      this.statusIndicatorTarget.innerHTML = `
        <div class="w-2 h-2 bg-gray-400 rounded-full mr-1.5"></div>
        Manual
      `
      this.statusIndicatorTarget.className = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
      
      console.log("Auto-refresh disabled")
    }
  }
  
  async refreshNow() {
    console.log("Manual refresh triggered")
    
    // Update button state
    this.setRefreshingState(true)
    
    try {
      const currentUrl = new URL(window.location)
      
      // Preserve current pagination and filter parameters
      const params = new URLSearchParams(currentUrl.search)
      const refreshUrl = new URL(currentUrl.origin + currentUrl.pathname)
      refreshUrl.search = params.toString()
      
      const response = await fetch(refreshUrl.toString(), {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // Validate that we have the expected data structure
        if (data && typeof data === 'object') {
          this.updatePage(data)
          this.showNotification("Activity logs refreshed", "success")
        } else {
          throw new Error('Invalid response data format')
        }
      } else {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
    } catch (error) {
      console.error("Error refreshing activity logs:", error)
      
      // More specific error messages
      let errorMessage = "Failed to refresh activity logs"
      if (error.message.includes('activityList')) {
        errorMessage = "UI refresh failed - please reload the page"
      } else if (error.message.includes('HTTP')) {
        errorMessage = `Server error: ${error.message}`
      } else if (error.message.includes('fetch')) {
        errorMessage = "Network error - please check your connection"
      }
      
      this.showNotification(errorMessage, "error")
    } finally {
      this.setRefreshingState(false)
    }
  }
  
  async streamNewActivities() {
    try {
      const response = await fetch(`/activity/stream?last_id=${this.lastActivityId}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        if (data.activities && data.activities.length > 0) {
          console.log(`Streaming ${data.activities.length} new activities`)
          this.prependNewActivities(data.activities)
          this.lastActivityId = data.last_id
          
          // Update activity count
          const currentCount = parseInt(this.activityCountTarget.textContent.match(/\d+/)[0]) || 0
          this.activityCountTarget.textContent = `(${currentCount + data.activities.length} events)`
          
          // Show notification for new activities
          this.showNotification(`${data.activities.length} new activities`, "info")
        }
      }
    } catch (error) {
      console.error("Error streaming new activities:", error)
    }
  }
  
  filterChanged() {
    // Auto-submit form when filters change
    console.log("Filters changed, submitting form")
    this.filterFormTarget.submit()
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
  
  updatePage(data) {
    // Update statistics
    if (data.stats) {
      if (this.hasTotalCountTarget) {
        this.totalCountTarget.textContent = data.stats.total_today
      }
      if (this.hasErrorCountTarget) {
        this.errorCountTarget.textContent = data.stats.errors_today
      }
      if (this.hasSignalCountTarget) {
        this.signalCountTarget.textContent = data.stats.signals_today
      }
      if (this.hasOrderCountTarget) {
        this.orderCountTarget.textContent = data.stats.orders_today
      }
    }
    
    // Update activity list - check if target exists
    if (data.activities && this.hasActivityListTarget) {
      this.renderActivities(data.activities)
      
      // Update activity count with pagination info if available
      if (this.hasActivityCountTarget) {
        let countText = `(${data.activities.length} events)`
        
        // Check if we have pagination information in the data
        if (data.pagination) {
          countText = `(Page ${data.pagination.current_page} of ${data.pagination.total_pages} - ${data.pagination.total_count} total events)`
        }
        
        this.activityCountTarget.textContent = countText
      }
    } else if (data.activities) {
      console.warn("Activity list target not found, trying manual DOM update")
      // Fallback: try to find the element manually
      const activityListElement = document.querySelector('[data-activity-logs-target="activityList"]')
      if (activityListElement) {
        this.renderActivitiesInElement(activityListElement, data.activities)
        
        // Update activity count
        const activityCountElement = document.querySelector('[data-activity-logs-target="activityCount"]')
        if (activityCountElement) {
          let countText = `(${data.activities.length} events)`
          
          if (data.pagination) {
            countText = `(Page ${data.pagination.current_page} of ${data.pagination.total_pages} - ${data.pagination.total_count} total events)`
          }
          
          activityCountElement.textContent = countText
        }
      }
    }
  }
  
  renderActivities(activities) {
    if (!this.hasActivityListTarget) {
      console.warn("Activity list target not available")
      return
    }
    
    this.renderActivitiesInElement(this.activityListTarget, activities)
  }
  
  renderActivitiesInElement(element, activities) {
    if (activities.length === 0) {
      element.innerHTML = this.getEmptyStateHTML()
      return
    }
    
    const activitiesHTML = activities.map(activity => this.renderActivity(activity)).join('')
    element.innerHTML = `<div class="min-w-full">${activitiesHTML}</div>`
  }
  
  prependNewActivities(activities) {
    if (!this.hasActivityListTarget) {
      console.warn("Activity list target not available for prepending")
      return
    }
    
    const container = this.activityListTarget.querySelector('.min-w-full')
    if (!container) {
      this.renderActivities(activities)
      return
    }
    
    const newActivitiesHTML = activities.map(activity => this.renderActivity(activity)).join('')
    container.insertAdjacentHTML('afterbegin', newActivitiesHTML)
    
    // Highlight new activities
    activities.forEach(activity => {
      const element = document.querySelector(`[data-activity-id="${activity.id}"]`)
      if (element) {
        element.classList.add('bg-blue-50', 'border-l-4', 'border-blue-400')
        setTimeout(() => {
          element.classList.remove('bg-blue-50', 'border-l-4', 'border-blue-400')
        }, 3000)
      }
    })
  }
  
  renderActivity(activity) {
    const detailsButton = activity.details && Object.keys(activity.details).length > 0 
      ? `<button class="ml-4 text-xs text-blue-600 hover:text-blue-800" onclick="toggleDetails('${activity.id}')">Details</button>`
      : ''
    
    const detailsSection = activity.details && Object.keys(activity.details).length > 0
      ? `<div id="details-${activity.id}" class="hidden mt-2 p-3 bg-gray-50 rounded text-xs">
           <pre class="text-gray-700 whitespace-pre-wrap">${JSON.stringify(activity.details, null, 2)}</pre>
         </div>`
      : ''
    
    return `
      <div class="flex items-start px-4 sm:px-6 py-4 border-b border-gray-100 hover:bg-gray-50 transition-colors" data-activity-id="${activity.id}">
        <!-- Timestamp -->
        <div class="flex-shrink-0 w-32 sm:w-40">
          <div class="text-xs text-gray-500">${activity.formatted_time}</div>
          <div class="text-xs text-gray-400">${activity.time_ago}</div>
        </div>
        
        <!-- Badges -->
        <div class="flex-shrink-0 flex flex-col space-y-1 mx-4">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${activity.level_badge_class}">
            ${activity.level.toUpperCase()}
          </span>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${activity.type_badge_class}">
            ${this.humanizeEventType(activity.event_type)}
          </span>
        </div>
        
        <!-- Content -->
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <p class="text-sm text-gray-900">${activity.message}</p>
              ${activity.symbol ? `<p class="mt-1 text-xs text-gray-500">Symbol: <span class="font-medium">${activity.symbol}</span></p>` : ''}
              ${activity.user ? `<p class="mt-1 text-xs text-gray-500">User: <span class="font-medium">${activity.user}</span></p>` : ''}
            </div>
            ${detailsButton}
          </div>
          ${detailsSection}
        </div>
      </div>
    `
  }
  
  getEmptyStateHTML() {
    return `
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A10.003 10.003 0 0124 26c4.21 0 7.813 2.602 9.288 6.286M30 14a6 6 0 11-12 0 6 6 0 0112 0zm12 6a4 4 0 11-8 0 4 4 0 018 0zm-28 0a4 4 0 11-8 0 4 4 0 018 0z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No activity logs</h3>
        <p class="mt-1 text-sm text-gray-500">No events match your current filters.</p>
        <div class="mt-6">
          <a href="/activity" class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
            Clear Filters
          </a>
        </div>
      </div>
    `
  }
  
  getLastActivityId() {
    const activities = document.querySelectorAll('[data-activity-id]')
    if (activities.length === 0) return 0
    
    const ids = Array.from(activities).map(el => parseInt(el.dataset.activityId))
    return Math.max(...ids)
  }
  
  humanizeEventType(eventType) {
    return eventType.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }
  
  showNotification(message, type = 'info') {
    // Reuse the notification system from other controllers
    const now = Date.now()
    this.lastNotification = this.lastNotification || 0
    if (now - this.lastNotification < 1000) return
    this.lastNotification = now
    
    // Create or get notification container
    let container = document.getElementById('notification-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'notification-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2 pointer-events-none'
      container.style.maxWidth = '384px'
      document.body.appendChild(container)
    }
    
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
            <button class="inline-flex rounded-md ${bgColor} text-gray-400 hover:text-gray-500 focus:outline-none" onclick="this.closest('.notification-item').remove()">
              <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    notification.classList.add('notification-item')
    container.appendChild(notification)
    
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
      notification.classList.add('translate-x-0', 'opacity-100')
    }, 100)
    
    setTimeout(() => {
      if (notification.parentNode) {
        notification.classList.add('translate-x-full', 'opacity-0')
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove()
            if (container.children.length === 0) {
              container.remove()
            }
          }
        }, 300)
      }
    }, 3000)
  }
} 