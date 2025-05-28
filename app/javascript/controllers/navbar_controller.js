import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu"]

  connect() {
    this.mobileMenuIsOpen = false
  }

  toggleMobileMenu() {
    this.mobileMenuIsOpen = !this.mobileMenuIsOpen
    
    if (this.mobileMenuIsOpen) {
      this.mobileMenuTarget.classList.remove("hidden")
    } else {
      this.mobileMenuTarget.classList.add("hidden")
    }
  }
} 