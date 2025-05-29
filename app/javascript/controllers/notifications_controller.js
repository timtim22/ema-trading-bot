import { Controller } from "@hotwired/stimulus"

// Legacy notifications controller - redirects to global Toast system
export default class extends Controller {
  
  showNotification(message, type = 'info') {
    window.Toast.show(message, type)
  }
  
  success(message) {
    window.Toast.success(message)
  }
  
  error(message) {
    window.Toast.error(message)
  }
  
  warning(message, warningKey = null) {
    window.Toast.warning(message, false, warningKey)
  }
  
  info(message) {
    window.Toast.info(message)
  }
} 