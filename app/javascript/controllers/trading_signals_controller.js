import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["signalsTable", "signalsTableBody", "emptyState"]
  static values = { userId: Number }
  
  connect() {
    console.log("🔌 TradingSignals controller connected")
    this.setupActionCable()
    this.setupAudioContext()
  }
  
  disconnect() {
    console.log("🔌 TradingSignals controller disconnected")
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.marketSubscription) {
      this.marketSubscription.unsubscribe()
    }
  }
  
  setupActionCable() {
    console.log("📡 Setting up ActionCable for trading signals...")
    
    this.consumer = createConsumer()
    
    // Subscribe to user-specific trading signals channel
    this.subscription = this.consumer.subscriptions.create(
      { 
        channel: "TradingSignalsChannel",
        user_id: this.userIdValue
      },
      {
        connected: () => {
          console.log("✅ Connected to TradingSignalsChannel")
        },
        
        disconnected: () => {
          console.log("❌ Disconnected from TradingSignalsChannel")
        },
        
        rejected: () => {
          console.log("🚫 TradingSignalsChannel subscription rejected")
        },
        
        received: (data) => {
          console.log("📨 Received trading signal data:", data)
          this.handleTradingSignal(data)
        }
      }
    )
    
    // Also subscribe to general market channel for signal notifications
    this.marketSubscription = this.consumer.subscriptions.create(
      "MarketChannel",
      {
        received: (data) => {
          if (data.type === "trading_signal") {
            console.log("📊 Received market signal notification:", data)
            this.showSignalNotification(data)
          }
        }
      }
    )
  }
  
  setupAudioContext() {
    // Enable audio on first user interaction
    const enableAudio = () => {
      if (!this.audioContext) {
        try {
          this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
          console.log("🔊 Audio context created")
        } catch (error) {
          console.log("Could not create audio context:", error)
        }
      }
      
      if (this.audioContext && this.audioContext.state === 'suspended') {
        this.audioContext.resume().then(() => {
          console.log("🔊 Audio context resumed")
        }).catch(error => {
          console.log("Could not resume audio context:", error)
        })
      }
      
      // Remove listeners after first interaction
      document.removeEventListener('click', enableAudio)
      document.removeEventListener('keydown', enableAudio)
    }
    
    // Listen for user interaction to enable audio
    document.addEventListener('click', enableAudio, { once: true })
    document.addEventListener('keydown', enableAudio, { once: true })
  }
  
  handleTradingSignal(data) {
    if (data.type === "trading_signal") {
      const signal = data.signal
      console.log(`🚨 New ${signal.signal_type} signal for ${signal.symbol} at ${signal.formatted_price}`)
      
      // Add signal to the table
      this.addSignalToTable(signal)
      
      // Show notification
      this.showSignalNotification(signal)
      
      // Dispatch event for chart controller to add markers
      const chartEvent = new CustomEvent('trading_signal', {
        detail: {
          symbol: signal.symbol,
          signal_type: signal.signal_type,
          price: signal.price,
          timestamp: signal.timestamp,
          ema5: signal.ema5,
          ema8: signal.ema8,
          ema22: signal.ema22
        },
        bubbles: true,
        cancelable: true
      })
      
      console.log(`📊 Dispatching trading_signal event for chart markers:`, chartEvent.detail)
      document.dispatchEvent(chartEvent)
      console.log(`📊 trading_signal event dispatched successfully`)
      
      // Play sound notification
      this.playNotificationSound()
    }
  }
  
  addSignalToTable(signal) {
    console.log("📝 Adding signal to table:", signal)
    
    if (!this.hasSignalsTableBodyTarget) {
      console.error("❌ No signals table body target found")
      return
    }
    
    // Check if we have an empty state row
    const emptyStateRow = this.signalsTableBodyTarget.querySelector('[data-trading-signals-target="emptyState"]')
    if (emptyStateRow) {
      console.log("🗑️ Removing empty state row")
      emptyStateRow.remove()
    }
    
    // Create new row element
    const newRow = document.createElement('tr')
    newRow.className = 'hover:bg-gray-50 bg-yellow-50 animate-pulse'
    newRow.innerHTML = this.createSignalRowHTML(signal)
    
    // Insert at the beginning of the table body
    this.signalsTableBodyTarget.insertBefore(newRow, this.signalsTableBodyTarget.firstChild)
    
    // Remove highlight after 3 seconds
    setTimeout(() => {
      newRow.classList.remove('bg-yellow-50', 'animate-pulse')
      newRow.classList.add('transition-colors', 'duration-1000')
    }, 3000)
    
    // Limit to 10 rows (remove oldest if more than 10)
    const allRows = this.signalsTableBodyTarget.querySelectorAll('tr')
    if (allRows.length > 10) {
      console.log(`🧹 Removing oldest row (total: ${allRows.length})`)
      allRows[allRows.length - 1].remove()
    }
    
    console.log("✅ Signal added to table successfully")
  }
  
  createSignalRowHTML(signal) {
    const signalIcon = signal.signal_type === 'buy' ? '📈' : '📉'
    const dotColor = signal.signal_type === 'buy' ? 'bg-green-400' : 'bg-red-400'
    const textColor = signal.signal_type === 'buy' ? 'text-green-600' : 'text-red-600'
    
    // Format timestamp to match server-side formatting (MM/DD HH:MM) in EDT/EST
    const timestamp = new Date(signal.timestamp * 1000)
    const edtDate = new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/New_York',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).formatToParts(timestamp)
    
    const month = edtDate.find(part => part.type === 'month').value
    const day = edtDate.find(part => part.type === 'day').value
    const hour = edtDate.find(part => part.type === 'hour').value
    const minute = edtDate.find(part => part.type === 'minute').value
    const formatted_date_time = `${month}/${day} ${hour}:${minute}`
    
    return `
      <td class="px-4 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono">${formatted_date_time}</td>
      <td class="px-4 sm:px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">${signal.symbol}</td>
      <td class="px-4 sm:px-6 py-4 whitespace-nowrap text-sm">
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${signal.badge_class}">
          <span class="w-2 h-2 ${dotColor} rounded-full mr-1.5"></span>
          ${signalIcon} ${signal.signal_type.charAt(0).toUpperCase() + signal.signal_type.slice(1)} (EMA Crossover)
        </span>
      </td>
      <td class="hidden lg:table-cell px-4 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono">${signal.ema5.toFixed(2)}</td>
      <td class="hidden lg:table-cell px-4 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono">${signal.ema8.toFixed(2)}</td>
      <td class="hidden lg:table-cell px-4 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono">${signal.ema22.toFixed(2)}</td>
      <td class="px-4 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        <span class="${textColor}">Signal @ ${signal.formatted_price}</span>
      </td>
    `
  }
  
  showSignalNotification(signal) {
    try {
      const signalType = signal.signal_type
      const symbol = signal.symbol
      const price = signal.formatted_price || `$${signal.price.toFixed(2)}`
      const icon = signalType === 'buy' ? '📈' : '📉'
      
      console.log(`🔔 Creating notification for ${signalType} signal: ${symbol} at ${price}`)
      
      // Create notification element
      const notification = document.createElement('div')
      notification.style.cssText = `
        position: fixed;
        top: 1rem;
        right: 1rem;
        z-index: 9999;
        max-width: 20rem;
        width: auto;
        min-width: 16rem;
        background: white;
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        border-radius: 0.75rem;
        pointer-events: auto;
        border: 1px solid rgba(0, 0, 0, 0.08);
        overflow: hidden;
        transform: translateX(100%);
        transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
        backdrop-filter: blur(8px);
      `
      
      const bgColor = signalType === 'buy' ? '#f0fdf4' : '#fef2f2'
      const borderColor = signalType === 'buy' ? '#22c55e' : '#ef4444'
      const textColor = signalType === 'buy' ? '#15803d' : '#dc2626'
      const iconBg = signalType === 'buy' ? '#dcfce7' : '#fee2e2'
      
      notification.innerHTML = `
        <div style="padding: 1rem; border-left: 4px solid ${borderColor}; background: ${bgColor};">
          <div style="display: flex; align-items: flex-start; gap: 0.75rem;">
            <div style="
              background: ${iconBg}; 
              border-radius: 50%; 
              width: 2.5rem; 
              height: 2.5rem; 
              display: flex; 
              align-items: center; 
              justify-content: center;
              flex-shrink: 0;
              border: 2px solid ${borderColor};
            ">
              <span style="font-size: 1.125rem;">${icon}</span>
            </div>
            <div style="flex: 1; min-width: 0;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                <div>
                  <p style="
                    font-size: 0.875rem; 
                    font-weight: 600; 
                    color: ${textColor}; 
                    margin: 0 0 0.25rem 0;
                    line-height: 1.25;
                  ">
                    ${signalType.toUpperCase()} Signal Detected!
                  </p>
                  <p style="
                    font-size: 0.8125rem; 
                    color: #6b7280; 
                    margin: 0;
                    font-weight: 500;
                  ">
                    <span style="font-weight: 600; color: #374151;">${symbol}</span> at <span style="font-weight: 600; color: ${textColor};">${price}</span>
                  </p>
                </div>
                <button 
                  onclick="try { const notif = this.closest('div[style*=\"position: fixed\"]'); if (notif && notif.parentNode) notif.parentNode.removeChild(notif); } catch(e) { console.debug('Element already removed'); }"
                  style="
                    background: rgba(255, 255, 255, 0.8);
                    border: none;
                    border-radius: 0.375rem;
                    padding: 0.25rem;
                    color: #9ca3af;
                    cursor: pointer;
                    transition: all 0.2s;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    width: 1.5rem;
                    height: 1.5rem;
                    margin-left: 0.5rem;
                    flex-shrink: 0;
                  "
                  onmouseover="this.style.background='rgba(255, 255, 255, 1)'; this.style.color='#6b7280';"
                  onmouseout="this.style.background='rgba(255, 255, 255, 0.8)'; this.style.color='#9ca3af';"
                >
                  <svg width="12" height="12" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      `
      
      // Add to body
      document.body.appendChild(notification)
      console.log("📱 Notification added to DOM")
      
      // Force reflow to ensure the element is rendered
      notification.offsetHeight
      
      // Animate in with a bounce effect
      setTimeout(() => {
        notification.style.transform = 'translateX(0) scale(1)'
        console.log("🎬 Notification animated in")
      }, 50)
      
      // Add a subtle pulse animation for the icon
      const iconElement = notification.querySelector('div[style*="border-radius: 50%"]')
      if (iconElement) {
        setTimeout(() => {
          iconElement.style.animation = 'pulse 2s infinite'
        }, 500)
      }
      
      // Auto remove after 6 seconds (slightly longer for better UX)
      setTimeout(() => {
        this.safeRemoveNotification(notification)
      }, 6000)
      
      console.log(`✅ Notification setup complete`)
    } catch (error) {
      console.error("❌ Error creating notification:", error)
    }
  }
  
  playNotificationSound() {
    console.log("🔊 Attempting to play notification sound...")
    
    // Create a simple beep sound using Web Audio API
    try {
      // Check if we have user interaction (required for audio in modern browsers)
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
        console.log("🎵 Audio context created")
      }
      
      // Resume audio context if suspended (browser policy)
      if (this.audioContext.state === 'suspended') {
        console.log("⏸️ Audio context suspended, attempting to resume...")
        this.audioContext.resume().then(() => {
          console.log("▶️ Audio context resumed, playing beep")
          this.playBeep()
        }).catch(error => {
          console.log("❌ Could not resume audio context:", error)
          this.playFallbackBeep()
        })
      } else {
        console.log("▶️ Audio context ready, playing beep")
        this.playBeep()
      }
    } catch (error) {
      console.log("❌ Could not play notification sound:", error)
      // Fallback: try to play a simple beep
      this.playFallbackBeep()
    }
  }
  
  playBeep() {
    try {
      console.log("🎵 Creating oscillator for beep...")
      const oscillator = this.audioContext.createOscillator()
      const gainNode = this.audioContext.createGain()
      
      oscillator.connect(gainNode)
      gainNode.connect(this.audioContext.destination)
      
      oscillator.frequency.value = 800
      oscillator.type = 'sine'
      
      gainNode.gain.setValueAtTime(0, this.audioContext.currentTime)
      gainNode.gain.linearRampToValueAtTime(0.3, this.audioContext.currentTime + 0.01)
      gainNode.gain.exponentialRampToValueAtTime(0.01, this.audioContext.currentTime + 0.5)
      
      oscillator.start(this.audioContext.currentTime)
      oscillator.stop(this.audioContext.currentTime + 0.5)
      
      console.log("✅ Beep sound played successfully")
    } catch (error) {
      console.log("❌ Could not play beep:", error)
      this.playFallbackBeep()
    }
  }
  
  playFallbackBeep() {
    // Create a data URL for a simple beep sound
    try {
      const audio = new Audio("data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OScTgwOUarm7blmGgU7k9n1unEiBC13yO/eizEIHWq+8+OWT")
      audio.volume = 0.3
      audio.play().catch(e => console.log("Fallback beep failed:", e))
    } catch (error) {
      console.log("Fallback beep failed:", error)
    }
  }
  
  safeRemoveNotification(notification) {
    try {
      if (notification && notification.parentNode) {
        notification.style.transform = 'translateX(100%) scale(0.95)'
        notification.style.opacity = '0'
        setTimeout(() => {
          try {
            if (notification && notification.parentNode) {
              notification.parentNode.removeChild(notification)
              console.log("🗑️ Notification safely removed")
            }
          } catch (error) {
            console.debug("Notification already removed:", error.message)
          }
        }, 400)
      }
    } catch (error) {
      console.debug("Error removing notification:", error.message)
    }
  }
} 