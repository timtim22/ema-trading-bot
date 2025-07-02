import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner", "message", "countdown"]
  
  connect() {
    this.dismissed = false // Track dismissal state for current page load only
    this.checkMarketHours()
    // Check every minute for market hours changes
    this.intervalId = setInterval(() => {
      this.checkMarketHours()
    }, 60000) // 60 seconds
  }
  
  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }
  
  checkMarketHours() {
    const now = new Date()
    const edtTime = new Date(now.toLocaleString("en-US", {timeZone: "America/New_York"}))
    
    const dayOfWeek = edtTime.getDay() // 0 = Sunday, 6 = Saturday
    const hour = edtTime.getHours()
    const minute = edtTime.getMinutes()
    const currentMinutes = hour * 60 + minute
    
    // Market hours: 9:30 AM - 4:00 PM EDT (570 - 960 minutes)
    const marketOpenMinutes = 9 * 60 + 30  // 9:30 AM = 570 minutes
    const marketCloseMinutes = 16 * 60     // 4:00 PM = 960 minutes
    
    let isMarketClosed = false
    let message = ""
    let showCountdown = false
    
    // Check if it's weekend
    if (dayOfWeek === 0 || dayOfWeek === 6) {
      isMarketClosed = true
      message = this.getWeekendMessage(dayOfWeek, edtTime)
    }
    // Check if it's before market open on weekday
    else if (currentMinutes < marketOpenMinutes) {
      isMarketClosed = true
      message = this.getPreMarketMessage(marketOpenMinutes - currentMinutes)
      showCountdown = true
    }
    // Check if it's after market close on weekday
    else if (currentMinutes >= marketCloseMinutes) {
      isMarketClosed = true
      message = this.getAfterHoursMessage(edtTime)
    }
    
    // Update banner visibility and content
    if (isMarketClosed) {
      this.showBanner(message, showCountdown)
    } else {
      this.hideBanner()
    }
  }
  
  getWeekendMessage(dayOfWeek, edtTime) {
    const dayName = dayOfWeek === 0 ? "Sunday" : "Saturday"
    const nextMonday = this.getNextMonday(edtTime)
    const timeString = edtTime.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZone: 'America/New_York'
    })
    
    return `🏖️ Market Closed - ${dayName} ${timeString} EDT • Opens Monday at 9:30 AM EDT (${nextMonday})`
  }
  
  getPreMarketMessage(minutesUntilOpen) {
    const hours = Math.floor(minutesUntilOpen / 60)
    const minutes = minutesUntilOpen % 60
    
    let timeUntilOpen = ""
    if (hours > 0) {
      timeUntilOpen = `${hours}h ${minutes}m`
    } else {
      timeUntilOpen = `${minutes}m`
    }
    
    return `🌅 Market Opens in ${timeUntilOpen} • Trading hours: 9:30 AM - 4:00 PM EDT`
  }
  
  getAfterHoursMessage(edtTime) {
    const tomorrow = new Date(edtTime)
    tomorrow.setDate(tomorrow.getDate() + 1)
    
    // If tomorrow is Saturday, show Monday
    if (tomorrow.getDay() === 6) {
      tomorrow.setDate(tomorrow.getDate() + 2)
    }
    // If tomorrow is Sunday, show Monday  
    else if (tomorrow.getDay() === 0) {
      tomorrow.setDate(tomorrow.getDate() + 1)
    }
    
    const tomorrowString = tomorrow.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'short',
      day: 'numeric'
    })
    
    return `🌙 Market Closed - After Hours • Next open: ${tomorrowString} at 9:30 AM EDT`
  }
  
  getNextMonday(currentDate) {
    const nextMonday = new Date(currentDate)
    const daysUntilMonday = (8 - currentDate.getDay()) % 7 || 7
    nextMonday.setDate(currentDate.getDate() + daysUntilMonday)
    
    return nextMonday.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric'
    })
  }
  
  showBanner(message, showCountdown = false) {
    // Don't show if dismissed for this page load
    if (this.dismissed) {
      return
    }
    
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = message
    }
    
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove('hidden')
      this.bannerTarget.classList.add('flex')
    }
    
    // Update countdown if needed
    if (showCountdown && this.hasCountdownTarget) {
      this.updateCountdown()
    }
  }
  
  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add('hidden')
      this.bannerTarget.classList.remove('flex')
    }
  }
  
  updateCountdown() {
    // This could be enhanced to show a live countdown
    // For now, the message includes the time remaining
  }
  
  dismiss() {
    // Hide the banner and mark as dismissed for this page load only
    this.hideBanner()
    this.dismissed = true
  }
} 