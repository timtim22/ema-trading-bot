import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="profile-editor"
export default class extends Controller {
  static targets = [
    "firstNameView", "firstNameEdit",
    "lastNameView", "lastNameEdit", 
    "emailView", "emailEdit",
    "saveButtons", "passwordSection",
    "editButtonText", "form"
  ]

  connect() {
    this.isEditMode = false
  }

  toggleEditMode() {
    this.isEditMode = !this.isEditMode
    
    if (this.isEditMode) {
      this.showEditMode()
    } else {
      this.showViewMode()
    }
  }

  showEditMode() {
    // Hide view elements
    this.firstNameViewTarget.classList.add('hidden')
    this.lastNameViewTarget.classList.add('hidden')
    this.emailViewTarget.classList.add('hidden')
    
    // Show edit elements
    this.firstNameEditTarget.classList.remove('hidden')
    this.lastNameEditTarget.classList.remove('hidden')
    this.emailEditTarget.classList.remove('hidden')
    this.saveButtonsTarget.classList.remove('hidden')
    
    // Update button text
    this.editButtonTextTarget.textContent = 'Cancel Edit'
    
    // Focus on first input
    this.firstNameEditTarget.querySelector('input').focus()
  }

  showViewMode() {
    // Show view elements
    this.firstNameViewTarget.classList.remove('hidden')
    this.lastNameViewTarget.classList.remove('hidden')
    this.emailViewTarget.classList.remove('hidden')
    
    // Hide edit elements
    this.firstNameEditTarget.classList.add('hidden')
    this.lastNameEditTarget.classList.add('hidden')
    this.emailEditTarget.classList.add('hidden')
    this.saveButtonsTarget.classList.add('hidden')
    
    // Update button text
    this.editButtonTextTarget.textContent = 'Edit Profile'
  }

  cancelEdit() {
    this.isEditMode = false
    this.showViewMode()
    
    // Reset form to original values
    this.formTarget.reset()
  }

  togglePasswordSection() {
    if (this.passwordSectionTarget.classList.contains('hidden')) {
      this.passwordSectionTarget.classList.remove('hidden')
    } else {
      this.passwordSectionTarget.classList.add('hidden')
    }
  }

  hidePasswordSection() {
    this.passwordSectionTarget.classList.add('hidden')
  }
} 