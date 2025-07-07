import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["heroContainer", "chartContainer"]
  
  connect() {
    console.log("🏠 Home animations controller connected")
    this.animationIntervals = []
    this.animatedElements = new Set()
    
    // Only initialize if we have the hero container (homepage specific)
    if (this.hasHeroContainerTarget) {
      this.initializeAnimations()
    }
  }
  
  disconnect() {
    console.log("🏠 Home animations controller disconnecting - cleaning up")
    this.cleanup()
  }
  
  initializeAnimations() {
    this.initializeFloatingText()
    this.initializeGeometricShapes()
    this.initializeParticleEffects()
    this.initializeChartInteractions()
    this.initializeParallaxEffects()
  }
  
  initializeFloatingText() {
    const tradingMessages = [
      '+$1,247', 'PROFIT!', 'BUY SIGNAL', 'TREND UP', '+15.7%', 
      'BULLISH', 'AI TRADING', 'SUCCESS', 'GROWTH', 'WINNING'
    ]
    
    const interval = setInterval(() => {
      // Double-check we're still on the homepage
      if (!this.hasHeroContainerTarget) {
        clearInterval(interval)
        return
      }
      
      const message = tradingMessages[Math.floor(Math.random() * tradingMessages.length)]
      const x = Math.random() * (window.innerWidth - 100)
      const y = Math.random() * (window.innerHeight - 100)
      this.createFloatingText(message, x, y)
    }, 4000)
    
    this.animationIntervals.push(interval)
  }
  
  createFloatingText(text, x, y) {
    const floatingText = document.createElement('div')
    floatingText.textContent = text
    floatingText.style.cssText = `
      position: fixed;
      left: ${x}px;
      top: ${y}px;
      color: var(--accent-green);
      font-size: 14px;
      font-weight: 600;
      pointer-events: none;
      z-index: 9999;
      opacity: 0;
    `
    
    document.body.appendChild(floatingText)
    this.animatedElements.add(floatingText)
    
    const animation = floatingText.animate([
      { opacity: 0, transform: 'translateY(0) scale(0.8)' },
      { opacity: 1, transform: 'translateY(-50px) scale(1)' },
      { opacity: 0, transform: 'translateY(-100px) scale(1.2)' }
    ], {
      duration: 2000,
      easing: 'ease-out'
    })
    
    animation.onfinish = () => {
      this.safeRemoveElement(floatingText)
    }
    
    // Failsafe cleanup after 3 seconds
    setTimeout(() => {
      this.safeRemoveElement(floatingText)
    }, 3000)
  }
  
  initializeGeometricShapes() {
    const interval = setInterval(() => {
      // Double-check we're still on the homepage
      if (!this.hasHeroContainerTarget) {
        clearInterval(interval)
        return
      }
      
      this.createRandomGeometricShape()
    }, 3000)
    
    this.animationIntervals.push(interval)
  }
  
  createRandomGeometricShape() {
    if (!this.hasHeroContainerTarget) return
    
    const shapes = ['triangle', 'hexagon', 'diamond']
    const randomShape = shapes[Math.floor(Math.random() * shapes.length)]
    
    const shape = document.createElement('div')
    shape.className = `geometric-shape ${randomShape}`
    shape.style.cssText = `
      left: ${Math.random() * 100}%;
      animation-delay: ${Math.random() * 5}s;
      animation-duration: ${15 + Math.random() * 10}s;
    `
    
    this.heroContainerTarget.appendChild(shape)
    this.animatedElements.add(shape)
    
    // Remove shape after animation
    setTimeout(() => {
      this.safeRemoveElement(shape)
    }, 25000)
  }
  
  initializeParticleEffects() {
    const interval = setInterval(() => {
      // Double-check we're still on the homepage
      if (!this.hasHeroContainerTarget) {
        clearInterval(interval)
        return
      }
      
      this.createSparkle()
    }, 2000)
    
    this.animationIntervals.push(interval)
  }
  
  createSparkle() {
    if (!this.hasHeroContainerTarget) return
    
    const sparkle = document.createElement('div')
    sparkle.className = 'sparkle'
    sparkle.style.cssText = `
      position: absolute;
      left: ${Math.random() * 100}%;
      top: ${Math.random() * 100}%;
      width: 4px;
      height: 4px;
      background: var(--accent-green);
      border-radius: 50%;
      animation: sparkleAnimation 3s ease-out forwards;
      pointer-events: none;
    `
    
    this.heroContainerTarget.appendChild(sparkle)
    this.animatedElements.add(sparkle)
    
    setTimeout(() => {
      this.safeRemoveElement(sparkle)
    }, 3000)
  }
  
  initializeChartInteractions() {
    if (this.hasChartContainerTarget) {
      this.chartContainerTarget.addEventListener('click', this.handleChartClick.bind(this))
    }
  }
  
  handleChartClick() {
    if (!this.hasChartContainerTarget) return
    
    const candlesticks = this.chartContainerTarget.querySelectorAll('.candlestick')
    candlesticks.forEach((stick, index) => {
      stick.animate([
        { transform: 'scaleY(1) rotateX(0deg)' },
        { transform: 'scaleY(1.5) rotateX(360deg)' },
        { transform: 'scaleY(1) rotateX(0deg)' }
      ], {
        duration: 1000,
        delay: index * 100,
        easing: 'ease-in-out'
      })
    })
  }
  
  initializeParallaxEffects() {
    if (!this.hasHeroContainerTarget) return
    
    this.handleMouseMove = (e) => {
      if (!this.hasHeroContainerTarget) return
      
      const centerX = window.innerWidth / 2
      const centerY = window.innerHeight / 2
      const deltaX = (e.clientX - centerX) / centerX
      const deltaY = (e.clientY - centerY) / centerY
      
      // Layer 1: Slow movement (background elements)
      const layer1 = this.heroContainerTarget.querySelectorAll('.dna-helix, .radar-container')
      layer1.forEach(element => {
        const x = deltaX * 5
        const y = deltaY * 5
        element.style.transform = `translate(${x}px, ${y}px)`
      })
      
      // Layer 2: Medium movement (geometric shapes)
      const layer2 = this.heroContainerTarget.querySelectorAll('.geometric-shape')
      layer2.forEach(element => {
        const x = deltaX * 10
        const y = deltaY * 10
        element.style.transform = `translate(${x}px, ${y}px)`
      })
    }
    
    document.addEventListener('mousemove', this.handleMouseMove)
  }
  
  safeRemoveElement(element) {
    try {
      if (element && element.parentNode) {
        element.parentNode.removeChild(element)
        this.animatedElements.delete(element)
      }
    } catch (error) {
      // Silently handle the case where element is already removed
      console.debug("Element already removed:", error.message)
    }
  }
  
  cleanup() {
    // Clear all intervals
    this.animationIntervals.forEach(interval => clearInterval(interval))
    this.animationIntervals = []
    
    // Remove all animated elements
    this.animatedElements.forEach(element => {
      this.safeRemoveElement(element)
    })
    this.animatedElements.clear()
    
    // Remove event listeners
    if (this.handleMouseMove) {
      document.removeEventListener('mousemove', this.handleMouseMove)
      this.handleMouseMove = null
    }
    
    if (this.hasChartContainerTarget) {
      this.chartContainerTarget.removeEventListener('click', this.handleChartClick)
    }
    
    console.log("🧹 Home animations cleaned up")
  }
} 