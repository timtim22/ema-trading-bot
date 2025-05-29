import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="help-modal"
export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Controller connected successfully
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("keydown", this.handleEscKey.bind(this))
    document.body.style.overflow = ""
  }

  open() {
    if (!this.hasModalTarget) {
      return
    }
    
    this.modalTarget.classList.remove("hidden")
    
    // Add event listener for ESC key
    document.addEventListener("keydown", this.handleEscKey.bind(this))
    
    // Prevent body scroll when modal is open
    document.body.style.overflow = "hidden"
    
    // Focus on the modal for accessibility
    this.modalTarget.focus()
  }

  close() {
    if (!this.hasModalTarget) {
      return
    }
    
    this.modalTarget.classList.add("hidden")
    
    // Remove event listener for ESC key
    document.removeEventListener("keydown", this.handleEscKey.bind(this))
    
    // Restore body scroll
    document.body.style.overflow = ""
  }

  // Close modal when clicking outside the modal content
  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  // Handle ESC key press
  handleEscKey(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // Prevent modal content clicks from closing the modal
  preventClose(event) {
    event.stopPropagation()
  }
} 