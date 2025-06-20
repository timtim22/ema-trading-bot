import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "userDropdown", "userDropdownMenu"]

  connect() {
    this.mobileMenuIsOpen = false
    this.userDropdownIsOpen = false
    
    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (this.hasUserDropdownTarget && !this.userDropdownTarget.contains(e.target)) {
        this.closeUserDropdown()
      }
    })
  }

  disconnect() {
    document.removeEventListener('click', this.closeDropdownOnClickOutside)
  }

  toggleMobileMenu() {
    this.mobileMenuIsOpen = !this.mobileMenuIsOpen
    
    if (this.mobileMenuIsOpen) {
      this.mobileMenuTarget.classList.remove("hidden")
      // Add slide-down animation
      this.mobileMenuTarget.style.animation = 'slideDown 0.3s ease-out'
    } else {
      // Add slide-up animation before hiding
      this.mobileMenuTarget.style.animation = 'slideUp 0.3s ease-out'
      setTimeout(() => {
        this.mobileMenuTarget.classList.add("hidden")
      }, 300)
    }
  }

  toggleUserDropdown(event) {
    event.preventDefault()
    event.stopPropagation()
    
    this.userDropdownIsOpen = !this.userDropdownIsOpen
    
    if (this.userDropdownIsOpen) {
      this.openUserDropdown()
    } else {
      this.closeUserDropdown()
    }
  }

  openUserDropdown() {
    if (this.hasUserDropdownMenuTarget) {
      this.userDropdownMenuTarget.classList.remove("hidden")
      const button = this.element.querySelector('#user-menu-button')
      if (button) {
        button.setAttribute('aria-expanded', 'true')
      }
    }
  }

  closeUserDropdown() {
    if (this.hasUserDropdownMenuTarget) {
      this.userDropdownMenuTarget.classList.add("hidden")
      const button = this.element.querySelector('#user-menu-button')
      if (button) {
        button.setAttribute('aria-expanded', 'false')
      }
      this.userDropdownIsOpen = false
    }
  }
} 