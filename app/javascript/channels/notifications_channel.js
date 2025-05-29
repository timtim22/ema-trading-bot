import consumer from "./consumer"

const notificationsChannel = consumer.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log("Connected to NotificationsChannel")
  },

  disconnected() {
    console.log("Disconnected from NotificationsChannel")
  },

  received(data) {
    console.log("NotificationsChannel received:", data)
    
    // Handle different types of notifications
    switch(data.type) {
      case 'connection_established':
        console.log(data.message)
        break
        
      case 'error':
        this.showErrorNotification(data)
        break
        
      case 'warning':
        this.showWarningNotification(data)
        break
        
      case 'success':
        this.showSuccessNotification(data)
        break
        
      case 'info':
        this.showInfoNotification(data)
        break
        
      case 'market_hours_warning':
        this.showMarketHoursWarning(data)
        break
        
      case 'data_unavailable_warning':
        this.showDataUnavailableWarning(data)
        break
        
      default:
        console.log('Unknown notification type:', data.type)
    }
  },
  
  showErrorNotification(data) {
    window.dispatchEvent(new CustomEvent('notifications:error', {
      detail: {
        message: data.message,
        persistent: data.persistent || false,
        context: data.context
      }
    }))
  },
  
  showWarningNotification(data) {
    window.dispatchEvent(new CustomEvent('notifications:warning', {
      detail: {
        message: data.message,
        persistent: data.persistent || false,
        warningKey: data.warning_key
      }
    }))
  },
  
  showSuccessNotification(data) {
    window.dispatchEvent(new CustomEvent('notifications:success', {
      detail: {
        message: data.message,
        persistent: data.persistent || false
      }
    }))
  },
  
  showInfoNotification(data) {
    window.dispatchEvent(new CustomEvent('notifications:info', {
      detail: {
        message: data.message,
        persistent: data.persistent || false
      }
    }))
  },
  
  showMarketHoursWarning(data) {
    const warningKey = `market_hours_${new Date().toDateString()}`
    window.dispatchEvent(new CustomEvent('notifications:warning', {
      detail: {
        message: data.message || 'Outside market hours - live data may be limited',
        persistent: false,
        warningKey: warningKey
      }
    }))
  },
  
  showDataUnavailableWarning(data) {
    const warningKey = `data_unavailable_${data.symbol || 'general'}`
    window.dispatchEvent(new CustomEvent('notifications:warning', {
      detail: {
        message: data.message || 'Market data temporarily unavailable',
        persistent: false,
        warningKey: warningKey
      }
    }))
  }
})

export default notificationsChannel 