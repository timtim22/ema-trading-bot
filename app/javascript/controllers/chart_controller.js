import { Controller } from "@hotwired/stimulus"

// Use the global LightweightCharts object from the standalone version
// This is different from importing { createChart }

export default class extends Controller {
  static targets = ["container"]
  static values = { 
    symbol: String,
    timeframe: String
  }

  connect() {
    console.log("📊 Chart controller connected - Enhanced with position management")
    
    // Set default values
    this.symbolValue = this.symbolValue || "AAPL"
    this.timeframeValue = this.timeframeValue || "5m"
    
    console.log(`📊 Initial values: symbol=${this.symbolValue}, timeframe=${this.timeframeValue}`)
    this.logCurrentState()
    
    // Initialize debounce tracking
    this.lastUpdateTime = 0
    this.updateDebounceMs = 1000 // Minimum 1 second between updates
    
    // Bind event handlers for real-time updates
    this.marketUpdateHandler = this.handleMarketUpdate.bind(this)
    this.marketPingHandler = this.handleMarketPing.bind(this)
    this.closePositionHandler = this.handleClosePosition.bind(this)
    this.tradingSignalHandler = this.handleTradingSignal.bind(this)
    
    // Listen for market updates
    document.addEventListener('market:update', this.marketUpdateHandler)
    document.addEventListener('market:ping', this.marketPingHandler)
    
    // Listen for trading signals for chart annotations
    document.addEventListener('trading_signal', this.tradingSignalHandler)
    
    // Listen for close position clicks
    document.addEventListener('click', this.closePositionHandler)
    
    this.initializeChart()
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('market:update', this.marketUpdateHandler)
    document.removeEventListener('market:ping', this.marketPingHandler)
    document.removeEventListener('trading_signal', this.tradingSignalHandler)
    document.removeEventListener('click', this.closePositionHandler)
    
    // Clean up chart
    if (this.chart) {
      this.chart.remove()
      this.chart = null
    }
  }

  initializeChart() {
    const container = this.containerTarget
    
    if (!container) {
      console.error("Chart container not found")
      return
    }
    
    console.log("Container found, initializing chart")
    
    // Show loading state
    container.innerHTML = '<div class="flex items-center justify-center h-full"><div class="text-gray-500"><div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-2"></div><p class="text-sm">Loading chart...</p></div></div>'
    
    // Load the chart library if not available
    if (typeof LightweightCharts === 'undefined') {
      this.loadChartLibrary(container)
      return
    }
    
    this.createChart(container)
  }
  
  loadChartLibrary(container) {
    console.log("Loading LightweightCharts library...")
    
    const script = document.createElement('script')
    script.src = 'https://cdn.jsdelivr.net/npm/lightweight-charts@4.2.3/dist/lightweight-charts.standalone.production.js'
    script.onload = () => {
      console.log("LightweightCharts loaded successfully")
      this.createChart(container)
    }
    script.onerror = () => {
      console.error("Failed to load LightweightCharts library")
      container.innerHTML = '<div class="flex items-center justify-center h-full"><div class="text-red-500"><svg class="h-8 w-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg><p class="text-sm">Failed to load chart</p></div></div>'
    }
    document.head.appendChild(script)
  }
  
  createChart(container) {
    try {
      // Clear container
      container.innerHTML = ''
      
      // Check if LightweightCharts is available
      if (typeof LightweightCharts === 'undefined') {
        throw new Error('LightweightCharts library not loaded')
      }
      
      console.log('Creating chart with LightweightCharts version:', LightweightCharts.version())
      
      // Create the chart
      this.chart = LightweightCharts.createChart(container, {
        width: container.clientWidth,
        height: container.clientHeight,
        layout: {
          background: { color: '#ffffff' },
          textColor: '#374151',
        },
        grid: {
          vertLines: { color: '#f3f4f6' },
          horzLines: { color: '#f3f4f6' },
        },
        timeScale: {
          timeVisible: true,
          secondsVisible: false,
          borderColor: '#d1d5db',
        },
        rightPriceScale: {
          borderColor: '#d1d5db',
        },
        crosshair: {
          mode: LightweightCharts.CrosshairMode.Normal,
        },
      })
      
      // Create series using v4.2.3 API
      this.candlestickSeries = this.chart.addCandlestickSeries({
        upColor: '#10b981',
        downColor: '#ef4444',
        borderVisible: false,
        wickUpColor: '#10b981',
        wickDownColor: '#ef4444',
      })
      
      // Create EMA line series with proper colors matching the legend
      this.ema5Series = this.chart.addLineSeries({
        color: '#3b82f6', // blue-500
        lineWidth: 2,
        title: 'EMA-5',
        priceLineVisible: false,
        lastValueVisible: false,
      })
      
      this.ema8Series = this.chart.addLineSeries({
        color: '#f97316', // orange-500
        lineWidth: 2,
        title: 'EMA-8',
        priceLineVisible: false,
        lastValueVisible: false,
      })
      
      this.ema22Series = this.chart.addLineSeries({
        color: '#ec4899', // pink-500
        lineWidth: 2,
        title: 'EMA-22',
        priceLineVisible: false,
        lastValueVisible: false,
      })
      
      console.log('Chart series created successfully:', {
        candlestick: !!this.candlestickSeries,
        ema5: !!this.ema5Series,
        ema8: !!this.ema8Series,
        ema22: !!this.ema22Series
      })
      
      // Test chart with minimal data immediately to check if chart setup is working
      console.log("🧪 Testing chart with minimal data...")
      try {
        const testData = [
          { time: Math.floor(Date.now() / 1000) - 120, open: 100, high: 101, low: 99, close: 100.5 },
          { time: Math.floor(Date.now() / 1000) - 60, open: 100.5, high: 102, low: 100, close: 101 },
          { time: Math.floor(Date.now() / 1000), open: 101, high: 102.5, low: 100.5, close: 102 }
        ]
        
        this.candlestickSeries.setData(testData)
        console.log("✅ Minimal test data set successfully")
        
        // Clear test data
        this.candlestickSeries.setData([])
        console.log("✅ Test data cleared successfully")
      } catch (testError) {
        console.error("❌ Chart test failed:", testError)
        console.log("❌ This indicates a fundamental issue with chart setup")
      }
      
      // Initialize signal markers array
      this.signalMarkers = []
      console.log("📍 Initialized signal markers array")
      
      // Make the chart responsive
      this.resizeObserver = new ResizeObserver(entries => {
        if (this.chart && entries.length > 0) {
          const { width, height } = entries[0].contentRect
          this.chart.applyOptions({ width, height })
        }
      })
      this.resizeObserver.observe(container)
      
      console.log("Chart created successfully")
      
      // Initialize with sample data immediately to ensure chart is ready for updates
      this.initializeWithSampleData()
      
      // Then fetch real data to replace sample data
      this.fetchImmediateData()
      
    } catch (error) {
      console.error("Error creating chart:", error)
      container.innerHTML = '<div class="flex items-center justify-center h-full"><div class="text-red-500"><svg class="h-8 w-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg><p class="text-sm">Chart initialization failed</p></div></div>'
    }
  }
  
  // Handle real-time market updates
  handleMarketUpdate(event) {
    if (!this.chart || !event.detail) return
    
    const { symbol, price, timestamp, ohlc, emas } = event.detail
    
    // Only update if this is for our current symbol
    if (symbol !== this.symbolValue) return
    
    // Debounce updates to prevent overwhelming the chart
    const now = Date.now()
    if (now - this.lastUpdateTime < this.updateDebounceMs) {
      console.log(`⏭️ Skipping update for ${symbol} (debounced)`)
      return
    }
    this.lastUpdateTime = now
    
    console.log(`🔄 Processing market update for ${symbol}: $${price}`)
    
    // DEBUG: Try to update positions from chart controller
    this.updatePositionsFromChart(symbol, price)
    
    // Validate OHLC data before updating
    if (ohlc && this.candlestickSeries && this.isValidOHLC(ohlc)) {
      try {
        // Check if chart has been initialized with data
        const existingData = this.candlestickSeries.data()
        
        if (!existingData || existingData.length === 0) {
          console.log(`📊 Chart not initialized for ${symbol}, fetching initial data...`)
          this.fetchImmediateData()
          return
        }
        
        // Validate timestamp and ensure it's in the correct format
        const validTimestamp = this.validateTimestamp(timestamp)
        
        // Create candlestick data with comprehensive validation
        const candlestickData = {
          time: validTimestamp,
          open: this.validatePrice(ohlc.open),
          high: this.validatePrice(ohlc.high),
          low: this.validatePrice(ohlc.low),
          close: this.validatePrice(ohlc.close)
        }
        
        console.log(`📊 Prepared candlestick data for ${symbol}:`, candlestickData)
        
        // Additional validation for OHLC relationships
        if (this.isValidCandlestick(candlestickData)) {
          // Check if this timestamp already exists in the data
          const lastDataPoint = existingData[existingData.length - 1]
          
          if (lastDataPoint && lastDataPoint.time === validTimestamp) {
            console.log(`🔄 Updating existing candlestick at time ${validTimestamp}`)
          } else {
            console.log(`➕ Adding new candlestick at time ${validTimestamp}`)
          }
          
          // Use update method with additional error handling
          this.candlestickSeries.update(candlestickData)
          console.log(`✅ Successfully updated candlestick for ${symbol}`)
        } else {
          console.warn(`❌ Invalid candlestick relationships for ${symbol}:`, candlestickData)
          // Try to fix the data and update anyway
          const fixedData = this.fixCandlestickData(candlestickData)
          if (fixedData) {
            console.log(`🔧 Using fixed candlestick data:`, fixedData)
            this.candlestickSeries.update(fixedData)
          }
        }
      } catch (error) {
        console.error('❌ Error updating candlestick series:', error)
        console.log('❌ OHLC data that caused error:', ohlc)
        console.log('❌ Candlestick data that caused error:', {
          time: this.validateTimestamp(timestamp),
          open: this.validatePrice(ohlc.open),
          high: this.validatePrice(ohlc.high),
          low: this.validatePrice(ohlc.low),
          close: this.validatePrice(ohlc.close)
        })
        
        // Try to recover by reinitializing the chart
        console.log('🔄 Attempting to recover by reinitializing chart...')
        this.initializeWithSampleData()
      }
    } else if (ohlc && !this.isValidOHLC(ohlc)) {
      console.warn(`❌ Invalid OHLC data for ${symbol}:`, ohlc)
    }
    
    // Update EMA lines if provided and series exist
    if (emas && this.candlestickSeries) {
      const existingData = this.candlestickSeries.data()
      
      if (existingData && existingData.length > 0) {
        const validTimestamp = this.validateTimestamp(timestamp)
        
        if (emas.ema5 && this.ema5Series && this.isValidEMAValue(emas.ema5)) {
          try {
            this.ema5Series.update({
              time: validTimestamp,
              value: this.validatePrice(emas.ema5)
            })
          } catch (error) {
            console.error('❌ Error updating EMA5 series:', error)
          }
        }
        if (emas.ema8 && this.ema8Series && this.isValidEMAValue(emas.ema8)) {
          try {
            this.ema8Series.update({
              time: validTimestamp,
              value: this.validatePrice(emas.ema8)
            })
          } catch (error) {
            console.error('❌ Error updating EMA8 series:', error)
          }
        }
        if (emas.ema22 && this.ema22Series && this.isValidEMAValue(emas.ema22)) {
          try {
            this.ema22Series.update({
              time: validTimestamp,
              value: this.validatePrice(emas.ema22)
            })
          } catch (error) {
            console.error('❌ Error updating EMA22 series:', error)
          }
        }
      }
    }
  }
  
  // Validate OHLC data structure
  isValidOHLC(ohlc) {
    if (!ohlc || typeof ohlc !== 'object') return false
    
    const requiredFields = ['open', 'high', 'low', 'close']
    for (const field of requiredFields) {
      if (ohlc[field] === null || ohlc[field] === undefined || isNaN(parseFloat(ohlc[field]))) {
        console.warn(`❌ Invalid ${field} value:`, ohlc[field])
        return false
      }
    }
    
    return true
  }
  
  // Validate candlestick data relationships (high >= low, etc.)
  isValidCandlestick(data) {
    const { open, high, low, close } = data
    
    if (high < low) {
      console.warn(`❌ High (${high}) cannot be less than low (${low})`)
      return false
    }
    
    if (high < Math.max(open, close)) {
      console.warn(`❌ High (${high}) cannot be less than max of open/close (${Math.max(open, close)})`)
      return false
    }
    
    if (low > Math.min(open, close)) {
      console.warn(`❌ Low (${low}) cannot be greater than min of open/close (${Math.min(open, close)})`)
      return false
    }
    
    return true
  }
  
  // Validate EMA value
  isValidEMAValue(value) {
    return value !== null && value !== undefined && !isNaN(parseFloat(value)) && parseFloat(value) > 0
  }
  
  // Validate and normalize timestamp
  validateTimestamp(timestamp) {
    console.log(`🕐 Validating timestamp:`, timestamp, typeof timestamp)
    
    if (!timestamp) {
      const fallback = Math.floor(Date.now() / 1000)
      console.log(`🕐 No timestamp provided, using current time: ${fallback}`)
      return fallback
    }
    
    let ts = timestamp
    
    // Handle different timestamp formats
    if (typeof timestamp === 'string') {
      ts = parseInt(timestamp)
    } else if (typeof timestamp === 'number') {
      ts = Math.floor(timestamp)
    }
    
    if (isNaN(ts)) {
      const fallback = Math.floor(Date.now() / 1000)
      console.warn(`❌ Timestamp is NaN: ${timestamp}, using current time: ${fallback}`)
      return fallback
    }
    
    // Convert milliseconds to seconds if needed
    if (ts > 9999999999) { // If timestamp is in milliseconds
      ts = Math.floor(ts / 1000)
      console.log(`🕐 Converted milliseconds to seconds: ${ts}`)
    }
    
    // Ensure timestamp is reasonable (not too far in past/future)
    const now = Math.floor(Date.now() / 1000)
    const oneWeek = 7 * 24 * 60 * 60 // Extended range for more flexibility
    
    if (ts < now - oneWeek || ts > now + oneWeek) {
      console.warn(`❌ Timestamp ${ts} seems invalid (too far from current time ${now}), using current time`)
      return now
    }
    
    console.log(`✅ Valid timestamp: ${ts}`)
    return ts
  }
  
  // Validate and sanitize price values
  validatePrice(price) {
    if (price === null || price === undefined) {
      console.warn(`❌ Price is null/undefined, using fallback`)
      return 100.0
    }
    
    const numPrice = parseFloat(price)
    if (isNaN(numPrice)) {
      console.warn(`❌ Price is NaN: ${price}, using fallback`)
      return 100.0
    }
    
    if (numPrice <= 0) {
      console.warn(`❌ Price is non-positive: ${numPrice}, using fallback`)
      return 100.0
    }
    
    return parseFloat(numPrice.toFixed(2))
  }
  
  // Fix invalid candlestick data
  fixCandlestickData(data) {
    try {
      const { time, open, high, low, close } = data
      
      // Ensure high is the maximum
      const fixedHigh = Math.max(open, high, low, close)
      
      // Ensure low is the minimum
      const fixedLow = Math.min(open, high, low, close)
      
      const fixedData = {
        time: time,
        open: open,
        high: fixedHigh,
        low: fixedLow,
        close: close
      }
      
      if (this.isValidCandlestick(fixedData)) {
        return fixedData
      }
      
      return null
    } catch (error) {
      console.error('❌ Error fixing candlestick data:', error)
      return null
    }
  }
  
  // Handle market pings (simpler updates)
  handleMarketPing(event) {
    if (!this.chart || !event.detail) return
    
    const { symbol, price, timestamp } = event.detail
    
    // Only update if this is for our current symbol
    if (symbol !== this.symbolValue) return
    
    // For pings, we'll just update the current price as a simple line update
    // In a real implementation, you might want to update the last candlestick
    console.log(`Chart ping for ${symbol}: $${price}`)
  }
  
  // Handle trading signals for chart annotations
  handleTradingSignal(event) {
    console.log("🎯 Chart controller received trading_signal event for:", event.detail?.symbol)
    
    if (!this.chart || !event.detail) {
      console.log("❌ Chart controller: No chart or event detail")
      return
    }
    
    const signal = event.detail
    
    // Only add markers for our current symbol
    if (signal.symbol !== this.symbolValue) {
      console.log(`⏭️ Chart controller: Skipping signal for ${signal.symbol}, current symbol is ${this.symbolValue}`)
      return
    }
    
    console.log(`📊 Adding ${signal.signal_type} signal marker for ${signal.symbol} at $${signal.price}`)
    
    this.addSignalMarker(signal)
  }
  
  // Add visual signal marker to the chart
  addSignalMarker(signal) {
    try {
      if (!this.candlestickSeries) {
        console.log("❌ No candlestick series available for markers")
        return
      }
      
      // Get the latest data point time from the chart instead of using Unix timestamp
      const chartData = this.candlestickSeries.data()
      let markerTime
      
      if (chartData && chartData.length > 0) {
        // Use the time of the last candlestick
        markerTime = chartData[chartData.length - 1].time
      } else {
        // Fallback to Unix timestamp
        markerTime = signal.timestamp || Math.floor(Date.now() / 1000)
      }
      
      const price = parseFloat(signal.price)
      const signalType = signal.signal_type
      
      // Create marker data using v4.2.3 API
      const marker = {
        time: markerTime,
        position: signalType === 'buy' ? 'belowBar' : 'aboveBar',
        color: signalType === 'buy' ? '#10b981' : '#ef4444', // green for buy, red for sell
        shape: signalType === 'buy' ? 'arrowUp' : 'arrowDown',
        text: `${signalType.toUpperCase()} Signal @ $${price.toFixed(2)}`,
        size: 1.5
      }
      
      // Add the new marker to our array
      this.signalMarkers.push(marker)
      
      // Use the v4.2.3 setMarkers API
      try {
        this.candlestickSeries.setMarkers(this.signalMarkers)
        console.log(`✅ Added ${signalType} signal marker (${this.signalMarkers.length} total)`)
      } catch (markerError) {
        console.error("❌ Error setting markers:", markerError)
      }
      
      // Show a brief notification on the chart
      this.showChartNotification(signal)
      
    } catch (error) {
      console.error('❌ Error adding signal marker:', error)
    }
  }
  
  // Show a brief notification overlay on the chart
  showChartNotification(signal) {
    try {
      const container = this.containerTarget
      if (!container) return
      
      // Remove any existing notifications to prevent overlap
      const existingNotifications = container.querySelectorAll('.chart-signal-notification')
      existingNotifications.forEach(notification => notification.remove())
      
      // Create notification element
      const notification = document.createElement('div')
      notification.className = 'chart-signal-notification absolute top-4 right-4 z-10 transform transition-all duration-500 ease-in-out'
      notification.style.cssText = `
        background: ${signal.signal_type === 'buy' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)'};
        color: white;
        padding: 0.75rem 1rem;
        border-radius: 0.5rem;
        font-size: 0.875rem;
        font-weight: 600;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
        backdrop-filter: blur(8px);
        border: 1px solid rgba(255, 255, 255, 0.2);
        max-width: 200px;
        pointer-events: none;
      `
      
      const icon = signal.signal_type === 'buy' ? '📈' : '📉'
      notification.innerHTML = `
        <div class="flex items-center space-x-2">
          <span style="font-size: 1.125rem;">${icon}</span>
          <div>
            <div style="font-weight: 700;">${signal.signal_type.toUpperCase()} Signal</div>
            <div style="font-size: 0.75rem; opacity: 0.9;">${signal.symbol} @ $${parseFloat(signal.price).toFixed(2)}</div>
          </div>
        </div>
      `
      
      // Position relative to chart container
      container.style.position = 'relative'
      container.appendChild(notification)
      
      // Animate in
      setTimeout(() => {
        notification.style.transform = 'translateX(0) scale(1)'
      }, 100)
      
      // Auto remove after 2 seconds (shorter to prevent overlap)
      setTimeout(() => {
        notification.style.transform = 'translateX(100%) scale(0.95)'
        notification.style.opacity = '0'
        setTimeout(() => {
          if (notification.parentNode) {
            notification.parentNode.removeChild(notification)
          }
        }, 500)
      }, 2000)
      
    } catch (error) {
      console.error('Error showing chart notification:', error)
    }
  }
  
  // Handle timeframe changes
  changeTimeframe(event) {
    console.log(`🔘 TIMEFRAME BUTTON CLICKED!`)
    console.log(`🔘 Event:`, event)
    console.log(`🔘 Current target:`, event.currentTarget)
    console.log(`🔘 Dataset:`, event.currentTarget.dataset)
    
    const newTimeframe = event.currentTarget.dataset.timeframe
    console.log(`🔘 New timeframe from dataset: ${newTimeframe}`)
    
    if (newTimeframe === this.timeframeValue) {
      console.log(`📊 Timeframe ${newTimeframe} already selected, skipping`)
      return
    }
    
    console.log(`📊 Changing timeframe from ${this.timeframeValue} to ${newTimeframe}`)
    console.log(`📊 Current data points: ${this.getDataPointsForTimeframe()}, interval: ${this.getIntervalMinutes()}min`)
    
    // Update timeframe value first
    this.timeframeValue = newTimeframe
    
    console.log(`📊 New data points: ${this.getDataPointsForTimeframe()}, interval: ${this.getIntervalMinutes()}min`)
    this.logCurrentState()
    
    // Update active button styling
    const buttons = this.element.querySelectorAll('[data-timeframe]')
    console.log(`🔘 Found ${buttons.length} timeframe buttons`)
    buttons.forEach(btn => {
      btn.classList.remove('bg-blue-50', 'text-blue-700', 'border-blue-500')
      btn.classList.add('text-gray-700', 'bg-white')
    })
    event.currentTarget.classList.remove('text-gray-700', 'bg-white')
    event.currentTarget.classList.add('bg-blue-50', 'text-blue-700', 'border-blue-500')
    
    // Clear existing chart data immediately to show the change
    if (this.chart && this.candlestickSeries) {
      console.log(`🧹 Clearing chart data for timeframe change to ${newTimeframe}`)
      this.candlestickSeries.setData([])
      this.ema5Series.setData([])
      this.ema8Series.setData([])
      this.ema22Series.setData([])
      
      // Clear signal markers
      if (this.signalMarkers) {
        this.signalMarkers = []
        this.candlestickSeries.setMarkers([])
      }
    }
    
    // Fetch data for the new timeframe
    if (this.chart) {
      this.fetchDataForTimeframe(newTimeframe)
    }
  }

  // Test method to verify button connectivity
  testButtonClick() {
    console.log(`🧪 TEST BUTTON CLICK METHOD CALLED!`)
    console.log(`🧪 This should appear when any timeframe button is clicked`)
    return true
  }
  
  // Fetch data for specific timeframe
  async fetchDataForTimeframe(timeframe) {
    try {
      console.log(`🔄 Fetching ${timeframe} data for ${this.symbolValue}...`)
      
      // Show loading state
      this.showLoadingState()
      
      const response = await fetch(`/dashboard/market_data?symbol=${this.symbolValue}&timeframe=${timeframe}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const result = await response.json()
      
      if (result.success && result.data) {
        console.log(`✅ Received ${timeframe} data for ${this.symbolValue}:`, result.data)
        console.log(`✅ Historical candles count: ${result.data.historical_candles?.length || 0}`)
        
        // Update chart with timeframe-specific data
        await this.updateChartWithTimeframeData(result.data)
        
        // Hide loading state
        this.hideLoadingState()
      } else {
        throw new Error(result.error || 'Failed to fetch timeframe data')
      }
    } catch (error) {
      console.error(`❌ Error fetching ${timeframe} data for ${this.symbolValue}:`, error)
      
      // Fall back to sample data with correct timeframe
      console.log(`🔄 Falling back to sample data for ${this.symbolValue} (${timeframe})`)
      console.log(`🔄 Sample data will have ${this.getDataPointsForTimeframe()} points with ${this.getIntervalMinutes()}min intervals`)
      
      const sampleData = this.generateSampleData()
      
      console.log(`📊 Setting sample data: ${sampleData.candlesticks.length} candlesticks, ${sampleData.ema5.length} EMA5, ${sampleData.ema8.length} EMA8, ${sampleData.ema22.length} EMA22`)
      
      this.candlestickSeries.setData(sampleData.candlesticks)
      this.ema5Series.setData(sampleData.ema5)
      this.ema8Series.setData(sampleData.ema8)
      this.ema22Series.setData(sampleData.ema22)
      this.chart.timeScale().fitContent()
      
      this.hideLoadingState()
    }
  }
  
  // Update chart with timeframe-specific data
  async updateChartWithTimeframeData(marketData) {
    if (!this.chart || !this.candlestickSeries) {
      console.warn("Chart not ready for timeframe data update")
      return
    }
    
    try {
      console.log(`📊 Processing market data for ${marketData.symbol}:`, marketData)
      
      // Use historical candles if available, otherwise generate from current data
      let candlesticks, ema5Data, ema8Data, ema22Data
      
      if (marketData.historical_candles && marketData.historical_candles.length > 0) {
        console.log(`📊 Using ${marketData.historical_candles.length} historical candles`)
        
        // Use real historical data with validation
        candlesticks = marketData.historical_candles
          .map(candle => {
            // Validate each field exists and is numeric
            if (!candle || typeof candle !== 'object') {
              console.warn(`❌ Invalid candle object:`, candle)
              return null
            }
            
            const time = candle.time
            const open = parseFloat(candle.open)
            const high = parseFloat(candle.high)
            const low = parseFloat(candle.low)
            const close = parseFloat(candle.close)
            
            // Check for null/undefined/NaN values
            if (!time || isNaN(open) || isNaN(high) || isNaN(low) || isNaN(close)) {
              console.warn(`❌ Invalid candle values:`, { time, open, high, low, close })
              return null
            }
            
            // Additional validation for positive values
            if (open <= 0 || high <= 0 || low <= 0 || close <= 0) {
              console.warn(`❌ Non-positive candle values:`, { time, open, high, low, close })
              return null
            }
            
            const candleData = { time, open, high, low, close }
            
            // Validate OHLC relationships
            if (!this.isValidCandlestick(candleData)) {
              console.warn(`❌ Invalid candlestick relationships:`, candleData)
              return null
            }
            
            return candleData
          })
          .filter(candle => candle !== null) // Remove invalid candles
        
        // Generate EMA data points for each valid candle
        ema5Data = candlesticks.map((candle, index) => {
          const value = this.interpolateEMA(marketData.emas.ema5, candle.close, index, candlesticks.length)
          return { time: candle.time, value: parseFloat(value.toFixed(2)) }
        }).filter(ema => this.isValidEMAValue(ema.value))
        
        ema8Data = candlesticks.map((candle, index) => {
          const value = this.interpolateEMA(marketData.emas.ema8, candle.close, index, candlesticks.length)
          return { time: candle.time, value: parseFloat(value.toFixed(2)) }
        }).filter(ema => this.isValidEMAValue(ema.value))
        
        ema22Data = candlesticks.map((candle, index) => {
          const value = this.interpolateEMA(marketData.emas.ema22, candle.close, index, candlesticks.length)
          return { time: candle.time, value: parseFloat(value.toFixed(2)) }
        }).filter(ema => this.isValidEMAValue(ema.value))
      } else {
        console.log(`📊 Generating historical data from current price`)
        
        // Fallback to generated data
        const historicalData = this.generateHistoricalDataFromCurrent(marketData)
        candlesticks = historicalData.candlesticks
        ema5Data = historicalData.ema5
        ema8Data = historicalData.ema8
        ema22Data = historicalData.ema22
      }
      
      // Final validation before setting data
      if (!candlesticks || candlesticks.length === 0) {
        console.error(`❌ No valid candlestick data for ${marketData.symbol}`)
        throw new Error('No valid candlestick data')
      }
      
      // Deep validation of all candlestick data
      const validatedCandlesticks = this.deepValidateCandlesticks(candlesticks)
      if (validatedCandlesticks.length === 0) {
        console.error(`❌ All candlestick data failed validation for ${marketData.symbol}`)
        throw new Error('All candlestick data invalid')
      }
      
      console.log(`📊 Final validation: ${validatedCandlesticks.length} candlesticks, ${ema5Data?.length || 0} EMA5, ${ema8Data?.length || 0} EMA8, ${ema22Data?.length || 0} EMA22`)
      
      // Log first few candlesticks for debugging
      console.log(`📊 Sample candlesticks:`, validatedCandlesticks.slice(0, 3))
      
      // Log the complete structure of the first candlestick for debugging
      if (validatedCandlesticks.length > 0) {
        const firstCandle = validatedCandlesticks[0]
        console.log(`🔍 First candlestick detailed structure:`, {
          time: firstCandle.time,
          timeType: typeof firstCandle.time,
          open: firstCandle.open,
          openType: typeof firstCandle.open,
          high: firstCandle.high,
          highType: typeof firstCandle.high,
          low: firstCandle.low,
          lowType: typeof firstCandle.low,
          close: firstCandle.close,
          closeType: typeof firstCandle.close,
          hasNullValues: Object.values(firstCandle).some(v => v === null || v === undefined),
          stringified: JSON.stringify(firstCandle)
        })
      }
      
      // Set the data with additional error handling and delay
      try {
        // Clear existing data first to prevent conflicts
        this.candlestickSeries.setData([])
        
        // Small delay to ensure chart is ready
        await new Promise(resolve => setTimeout(resolve, 50))
        
        // Use the new validation function instead of creating simple data
        console.log(`📊 Validating candlestick data with enhanced validation...`)
        const validCandlesticks = this.validateChartData(validatedCandlesticks, 'candlestick')
        
        if (validCandlesticks.length === 0) {
          console.log(`❌ No valid candlesticks after validation, creating fallback data`)
          const fallbackData = this.createSimpleValidData(50) // Create 50 data points as fallback
          this.candlestickSeries.setData(fallbackData)
          console.log(`✅ Successfully set ${fallbackData.length} fallback candlesticks`)
        } else {
          console.log(`📊 Setting ${validCandlesticks.length} validated candlesticks`)
          this.candlestickSeries.setData(validCandlesticks)
          console.log(`✅ Successfully set ${validCandlesticks.length} validated candlesticks`)
        }
      } catch (candleError) {
        console.error(`❌ Error setting candlestick data:`, candleError)
        console.log(`❌ Falling back to absolute minimal data...`)
        
        // Ultimate fallback: just 3 hardcoded data points with proper chronological order
        try {
          const now = Math.floor(Date.now() / 1000)
          const minimalData = [
            { time: now - 120, open: 100, high: 101, low: 99, close: 100.5 },
            { time: now - 60, open: 100.5, high: 102, low: 100, close: 101 },
            { time: now, open: 101, high: 102.5, low: 100.5, close: 102 }
          ]
          this.candlestickSeries.setData(minimalData)
          console.log(`✅ Minimal fallback successful with ${minimalData.length} candlesticks`)
        } catch (fallbackError) {
          console.error(`❌ Even minimal fallback failed:`, fallbackError)
          throw candleError
        }
      }
      
      // Set EMA data with enhanced validation
      if (ema5Data && ema5Data.length > 0) {
        try {
          await new Promise(resolve => setTimeout(resolve, 25))
          const validEma5 = this.validateChartData(ema5Data, 'line')
          if (validEma5.length > 0) {
            this.ema5Series.setData(validEma5)
            console.log(`✅ Successfully set ${validEma5.length} validated EMA5 points`)
          } else {
            // Fallback to simple EMA data
            const simpleEma5 = this.createSimpleEMAData(50, 105)
          this.ema5Series.setData(simpleEma5)
            console.log(`✅ Successfully set ${simpleEma5.length} fallback EMA5 points`)
          }
        } catch (emaError) {
          console.error(`❌ Error setting EMA5 data:`, emaError)
        }
      }
      
      if (ema8Data && ema8Data.length > 0) {
        try {
          await new Promise(resolve => setTimeout(resolve, 25))
          const validEma8 = this.validateChartData(ema8Data, 'line')
          if (validEma8.length > 0) {
            this.ema8Series.setData(validEma8)
            console.log(`✅ Successfully set ${validEma8.length} validated EMA8 points`)
          } else {
            // Fallback to simple EMA data
            const simpleEma8 = this.createSimpleEMAData(50, 110)
          this.ema8Series.setData(simpleEma8)
            console.log(`✅ Successfully set ${simpleEma8.length} fallback EMA8 points`)
          }
        } catch (emaError) {
          console.error(`❌ Error setting EMA8 data:`, emaError)
        }
      }
      
      if (ema22Data && ema22Data.length > 0) {
        try {
          await new Promise(resolve => setTimeout(resolve, 25))
          const validEma22 = this.validateChartData(ema22Data, 'line')
          if (validEma22.length > 0) {
            this.ema22Series.setData(validEma22)
            console.log(`✅ Successfully set ${validEma22.length} validated EMA22 points`)
          } else {
            // Fallback to simple EMA data
            const simpleEma22 = this.createSimpleEMAData(50, 115)
          this.ema22Series.setData(simpleEma22)
            console.log(`✅ Successfully set ${simpleEma22.length} fallback EMA22 points`)
          }
        } catch (emaError) {
          console.error(`❌ Error setting EMA22 data:`, emaError)
        }
      }
      
      // Fit content to show all data with delay
      await new Promise(resolve => setTimeout(resolve, 50))
      this.chart.timeScale().fitContent()
      
      console.log(`✅ Successfully updated chart with ${marketData.timeframe} timeframe data for ${marketData.symbol}`)
    } catch (error) {
      console.error("❌ Error updating chart with timeframe data:", error)
      console.log("❌ Market data that caused error:", marketData)
      
      // Fallback to sample data if real data fails
      console.log(`🔄 Falling back to sample data for ${marketData.symbol}`)
      this.initializeWithSampleData()
    }
  }
  
  // Deep validation of candlestick data to prevent null value errors
  deepValidateCandlesticks(candlesticks) {
    const validated = []
    
    for (let i = 0; i < candlesticks.length; i++) {
      const candle = candlesticks[i]
      
      // Check for null/undefined object
      if (!candle || typeof candle !== 'object') {
        console.warn(`❌ Skipping null/invalid candle at index ${i}:`, candle)
        continue
      }
      
      // Extract and validate each field
      const time = candle.time
      const open = candle.open
      const high = candle.high
      const low = candle.low
      const close = candle.close
      
      // Check for null/undefined values
      if (time === null || time === undefined ||
          open === null || open === undefined ||
          high === null || high === undefined ||
          low === null || low === undefined ||
          close === null || close === undefined) {
        console.warn(`❌ Skipping candle with null values at index ${i}:`, { time, open, high, low, close })
        continue
      }
      
      // Check for NaN values
      const numOpen = parseFloat(open)
      const numHigh = parseFloat(high)
      const numLow = parseFloat(low)
      const numClose = parseFloat(close)
      
      if (isNaN(numOpen) || isNaN(numHigh) || isNaN(numLow) || isNaN(numClose)) {
        console.warn(`❌ Skipping candle with NaN values at index ${i}:`, { open, high, low, close })
        continue
      }
      
      // Check for non-positive values
      if (numOpen <= 0 || numHigh <= 0 || numLow <= 0 || numClose <= 0) {
        console.warn(`❌ Skipping candle with non-positive values at index ${i}:`, { numOpen, numHigh, numLow, numClose })
        continue
      }
      
      // Validate OHLC relationships
      if (numHigh < numLow || numHigh < Math.max(numOpen, numClose) || numLow > Math.min(numOpen, numClose)) {
        console.warn(`❌ Fixing invalid OHLC relationships at index ${i}:`, { numOpen, numHigh, numLow, numClose })
        
        // Fix the relationships
        const fixedHigh = Math.max(numOpen, numHigh, numLow, numClose)
        const fixedLow = Math.min(numOpen, numHigh, numLow, numClose)
        
        validated.push({
          time: time,
          open: parseFloat(numOpen.toFixed(2)),
          high: parseFloat(fixedHigh.toFixed(2)),
          low: parseFloat(fixedLow.toFixed(2)),
          close: parseFloat(numClose.toFixed(2))
        })
      } else {
        // Valid candle - create a completely new object to avoid any reference issues
        validated.push({
          time: time,
          open: parseFloat(numOpen.toFixed(2)),
          high: parseFloat(numHigh.toFixed(2)),
          low: parseFloat(numLow.toFixed(2)),
          close: parseFloat(numClose.toFixed(2))
        })
      }
    }
    
    console.log(`📊 Deep validation: ${candlesticks.length} input → ${validated.length} valid candlesticks`)
    
    // Try creating minimal test data if validation fails
    if (validated.length === 0) {
      console.log(`🔄 Creating minimal test data as fallback...`)
      const now = Math.floor(Date.now() / 1000)
      return [
        { time: now - 120, open: 100.0, high: 101.0, low: 99.0, close: 100.5 },
        { time: now - 60, open: 100.5, high: 102.0, low: 100.0, close: 101.0 },
        { time: now, open: 101.0, high: 102.5, low: 100.5, close: 102.0 }
      ]
    }
    
    return validated
  }
  
  // Interpolate EMA values across historical data
  interpolateEMA(currentEMA, currentPrice, index, totalPoints) {
    // Validate inputs
    if (currentEMA === null || currentEMA === undefined || isNaN(currentEMA)) {
      console.warn(`❌ Invalid currentEMA:`, currentEMA)
      return currentPrice || 100 // Fallback to current price or default
    }
    
    if (currentPrice === null || currentPrice === undefined || isNaN(currentPrice)) {
      console.warn(`❌ Invalid currentPrice:`, currentPrice)
      return currentEMA || 100 // Fallback to EMA or default
    }
    
    // For the last point, use the actual EMA
    if (index === totalPoints - 1) {
      return parseFloat(currentEMA.toFixed(2))
    }
    
    // For historical points, interpolate between current EMA and price
    const factor = (index + 1) / totalPoints
    const interpolated = currentEMA * factor + currentPrice * (1 - factor)
    
    // Ensure result is valid
    if (isNaN(interpolated)) {
      console.warn(`❌ Interpolation resulted in NaN:`, { currentEMA, currentPrice, factor })
      return currentPrice || 100
    }
    
    return parseFloat(interpolated.toFixed(2))
  }
  
  // Generate sample data for testing
  generateSampleData() {
    const candlesticks = []
    const ema5 = []
    const ema8 = []
    const ema22 = []
    
    // Adjust data points based on timeframe
    const dataPoints = this.getDataPointsForTimeframe()
    const intervalMinutes = this.getIntervalMinutes()
    
    console.log(`📊 Generating ${dataPoints} sample data points for ${this.timeframeValue} timeframe (${intervalMinutes}min intervals)`)
    
    const now = new Date()
    let basePrice = 185 // Starting price for AAPL
    
    // Adjust base price for different symbols
    if (this.symbolValue === 'NVDA') basePrice = 484
    else if (this.symbolValue === 'MSFT') basePrice = 375
    else if (this.symbolValue === 'TSLA') basePrice = 241
    else if (this.symbolValue === 'GOOG') basePrice = 171
    else if (this.symbolValue === 'AMZN') basePrice = 178
    
    // Adjust volatility based on timeframe - longer timeframes should show more price movement
    let volatilityMultiplier = 1
    let trendStrength = 1
    
    switch (this.timeframeValue) {
      case '5m':
        volatilityMultiplier = 0.3  // Low volatility for 5-minute data
        trendStrength = 0.5
        break
      case '15m':
        volatilityMultiplier = 0.6  // Medium volatility for 15-minute data
        trendStrength = 0.8
        break
      case '1h':
        volatilityMultiplier = 1.2  // Higher volatility for hourly data
        trendStrength = 1.5
        break
      case '1d':
        volatilityMultiplier = 2.5  // Much higher volatility for daily data
        trendStrength = 3.0
        break
      default:
        volatilityMultiplier = 1
        trendStrength = 1
    }
    
    console.log(`📊 Using volatility multiplier: ${volatilityMultiplier}, trend strength: ${trendStrength}`)
    
    for (let i = 0; i < dataPoints; i++) {
      // Create timestamps in ascending order (older to newer)
      const time = new Date(now)
      time.setMinutes(time.getMinutes() - ((dataPoints - 1 - i) * intervalMinutes))
      
      // Generate realistic price movement with timeframe-appropriate volatility
      const trendComponent = Math.sin(i / (dataPoints / 4)) * trendStrength
      const randomComponent = (Math.random() - 0.5) * 2 * volatilityMultiplier
      const movement = trendComponent + randomComponent
      
      basePrice = Math.max(50, basePrice + movement) // Prevent negative prices
      
      const open = Math.max(1, basePrice) // Ensure positive
      const volatility = (0.5 + (Math.random() * 1.5)) * volatilityMultiplier
      let high = basePrice + Math.random() * volatility
      let low = basePrice - Math.random() * volatility
      let close = basePrice + (Math.random() - 0.5) * volatility
      
      // Ensure valid OHLC relationships
      high = Math.max(high, open, close, 1)
      low = Math.min(low, open, close)
      low = Math.max(low, 1) // Ensure positive
      close = Math.max(close, 1) // Ensure positive
      
      const timestamp = Math.floor(time.getTime() / 1000)
      
      // Validate before adding
      const candleData = {
        time: timestamp,
        open: parseFloat(open.toFixed(2)),
        high: parseFloat(high.toFixed(2)),
        low: parseFloat(low.toFixed(2)),
        close: parseFloat(close.toFixed(2))
      }
      
      // Double-check validity
      if (this.isValidCandlestick(candleData)) {
        candlesticks.push(candleData)
      } else {
        console.warn(`❌ Generated invalid sample candlestick:`, candleData)
        // Fix and add anyway
        candleData.high = Math.max(candleData.open, candleData.close, candleData.high)
        candleData.low = Math.min(candleData.open, candleData.close, candleData.low)
        candlesticks.push(candleData)
      }
      
      // Calculate EMAs (simplified for demo) with timeframe-appropriate smoothing
      const emaVolatility = volatilityMultiplier * 0.5
      const ema5Value = Math.max(1, basePrice + (Math.sin(i / 5) * emaVolatility))
      const ema8Value = Math.max(1, basePrice + (Math.sin(i / 8) * emaVolatility * 1.2))
      const ema22Value = Math.max(1, basePrice + (Math.sin(i / 22) * emaVolatility * 1.8))
      
      ema5.push({
        time: timestamp,
        value: parseFloat(ema5Value.toFixed(2))
      })
      
      ema8.push({
        time: timestamp,
        value: parseFloat(ema8Value.toFixed(2))
      })
      
      ema22.push({
        time: timestamp,
        value: parseFloat(ema22Value.toFixed(2))
      })
      
      basePrice = close // Use close as next open
    }
    
    // Sort all arrays by time to ensure chronological order
    candlesticks.sort((a, b) => a.time - b.time)
    ema5.sort((a, b) => a.time - b.time)
    ema8.sort((a, b) => a.time - b.time)
    ema22.sort((a, b) => a.time - b.time)
    
    console.log(`📊 Generated ${candlesticks.length} sample candlesticks for ${this.symbolValue} (${this.timeframeValue})`)
    console.log(`📊 Sample data time range: ${new Date(candlesticks[0]?.time * 1000).toLocaleString()} to ${new Date(candlesticks[candlesticks.length - 1]?.time * 1000).toLocaleString()}`)
    console.log(`📊 Price range: $${Math.min(...candlesticks.map(c => c.low)).toFixed(2)} - $${Math.max(...candlesticks.map(c => c.high)).toFixed(2)}`)
    
    return { candlesticks, ema5, ema8, ema22 }
  }
  
  getDataPointsForTimeframe() {
    switch (this.timeframeValue) {
      case '5m': return 288 // 24 hours of 5-minute candles
      case '15m': return 96  // 24 hours of 15-minute candles
      case '1h': return 168  // 7 days of hourly candles
      case '1d': return 90   // 90 days of daily candles
      default: return 100
    }
  }
  
  getIntervalMinutes() {
    switch (this.timeframeValue) {
      case '5m': return 5
      case '15m': return 15
      case '1h': return 60
      case '1d': return 1440 // 24 * 60
      default: return 5
    }
  }
  
  // Enhanced method to update positions from chart controller with notifications
  updatePositionsFromChart(symbol, price) {
    // Find all current price targets for this symbol
    const currentPriceTargets = document.querySelectorAll(`[data-positions-target="currentPrice"][data-symbol="${symbol}"]`)
    let updatedPositions = 0
    
    // Update current price displays
    currentPriceTargets.forEach((target) => {
      target.innerHTML = `$${parseFloat(price).toFixed(2)}`
      updatedPositions++
    })
    
    // Find and update P/L for this symbol
    const positionRows = document.querySelectorAll('tr[data-position-id]')
    let significantPnLChanges = []
    
    positionRows.forEach((row) => {
      const symbolCell = row.querySelector('td:first-child')
      if (symbolCell && symbolCell.textContent.trim() === symbol) {
        const pnlChange = this.updateRowPnL(row, price)
        if (pnlChange && Math.abs(pnlChange.percentage) >= 3) { // Significant change >= 3%
          significantPnLChanges.push(pnlChange)
        }
      }
    })
    
    // Show notification only for significant P/L changes (≥3%)
    if (significantPnLChanges.length > 0) {
      this.showPnLNotification(symbol, significantPnLChanges)
    }
    
    // Removed periodic update notifications - they were too frequent and not helpful
  }
  
  updateRowPnL(row, currentPrice) {
    try {
      // Get entry price from the row
      const entryPriceCell = row.querySelector('td:nth-child(2)')
      if (!entryPriceCell) return null
      
      const entryPriceText = entryPriceCell.textContent.replace('$', '').replace(',', '')
      const entryPrice = parseFloat(entryPriceText)
      
      if (isNaN(entryPrice) || entryPrice === 0) return null
      
      // Get previous P/L for comparison
      const pnlCell = row.querySelector('[data-positions-target="pnl"]')
      const previousPnlText = pnlCell ? pnlCell.textContent : '0%'
      const previousPnl = parseFloat(previousPnlText.replace(/[+%]/g, '')) || 0
      
      // Calculate P/L percentage
      const pnlPercentage = ((currentPrice - entryPrice) / entryPrice * 100)
      const formattedPnl = `${pnlPercentage >= 0 ? '+' : ''}${pnlPercentage.toFixed(2)}%`
      
      // Update P/L display
      if (pnlCell) {
        pnlCell.textContent = formattedPnl
        
        // Update color class with animation
        pnlCell.className = pnlCell.className.replace(/text-(green|red|gray)-600/g, '')
        if (pnlPercentage > 0) {
          pnlCell.classList.add('text-green-600')
        } else if (pnlPercentage < 0) {
          pnlCell.classList.add('text-red-600')
        } else {
          pnlCell.classList.add('text-gray-600')
        }
        
        // Add flash animation for significant changes
        const change = Math.abs(pnlPercentage - previousPnl)
        if (change >= 0.5) { // Flash for changes >= 0.5%
          pnlCell.style.transition = 'background-color 0.3s ease'
          pnlCell.style.backgroundColor = pnlPercentage > previousPnl ? '#dcfce7' : '#fef2f2'
          setTimeout(() => {
            pnlCell.style.backgroundColor = ''
          }, 1000)
        }
        
        // Removed verbose logging for performance
      }
      
      // Return change information
      return {
        percentage: pnlPercentage,
        formatted: formattedPnl,
        change: pnlPercentage - previousPnl,
        symbol: row.querySelector('td:first-child')?.textContent?.trim(),
        currentPrice: currentPrice,
        entryPrice: entryPrice
      }
    } catch (error) {
      console.error('Error updating P/L from chart controller:', error)
      return null
    }
  }
  
  // Handle close position button clicks
  handleClosePosition(event) {
    // Check if the clicked element is a close position button
    const closeButton = event.target.closest('[data-action*="closePosition"]')
    if (!closeButton) return
    
    event.preventDefault()
    
    const positionId = closeButton.dataset.positionId
    if (!positionId) {
      console.error('No position ID found on close button')
      return
    }
    
    this.closePosition(closeButton, positionId)
  }
  
  async closePosition(button, positionId) {
    const buttonText = button.querySelector('[data-positions-target="closeButtonText"]') || button.querySelector('span')
    const originalText = buttonText ? buttonText.textContent : 'Close'
    
    // Disable button and show loading state
    button.disabled = true
    if (buttonText) {
      buttonText.textContent = 'Closing...'
    }
    
    try {
      const response = await fetch(`/positions/${positionId}/close_manually`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (response.ok && data.success) {
        // Show success notification
        this.showNotification(data.message || 'Position closed successfully', 'success')
        
        // Remove the position row from the table
        const positionRow = button.closest('tr[data-position-id]')
        if (positionRow) {
          positionRow.style.transition = 'opacity 0.3s ease-out'
          positionRow.style.opacity = '0'
          setTimeout(() => {
            positionRow.remove()
            
            // Check if table is now empty and show empty state
            const remainingRows = document.querySelectorAll('tr[data-position-id]')
            if (remainingRows.length === 0) {
              this.showEmptyState()
            }
          }, 300)
        }
        
        // Position closed successfully
      } else {
        throw new Error(data.error || 'Failed to close position')
      }
    } catch (error) {
      console.error('Error closing position:', error)
      this.showNotification(`Error: ${error.message}`, 'error')
      
      // Re-enable button
      button.disabled = false
      if (buttonText) {
        buttonText.textContent = originalText
      }
    }
  }
  
  showEmptyState() {
    const tbody = document.querySelector('tbody')
    if (!tbody) return
    
    tbody.innerHTML = `
      <tr>
        <td colspan="7" class="px-4 sm:px-6 py-8 text-center">
          <div class="text-gray-500">
            <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
              <path d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A10.003 10.003 0 0124 26c4.21 0 7.813 2.602 9.288 6.286M30 14a6 6 0 11-12 0 6 6 0 0112 0zm12 6a4 4 0 11-8 0 4 4 0 018 0zm-28 0a4 4 0 11-8 0 4 4 0 018 0z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No active positions</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by configuring your trading bot.</p>
            <div class="mt-4">
              <button class="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 shadow-sm transition-all duration-200 hover:shadow-md">
                <svg class="-ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                </svg>
                Create Test Position
              </button>
            </div>
          </div>
        </td>
      </tr>
    `
  }
  
  showPnLNotification(symbol, pnlChanges) {
    // Only show if there are significant changes
    if (pnlChanges.length === 0) return
    
    const maxChange = Math.max(...pnlChanges.map(p => Math.abs(p.percentage)))
    const direction = pnlChanges[0].percentage > 0 ? '📈' : '📉'
    const type = pnlChanges[0].percentage > 0 ? 'success' : 'error'
    
    let message
    if (pnlChanges.length === 1) {
      message = `${direction} ${symbol} position moved ${pnlChanges[0].formatted} (${maxChange.toFixed(1)}% change)`
    } else {
      message = `${direction} ${symbol}: ${pnlChanges.length} positions with significant moves (up to ${maxChange.toFixed(1)}%)`
    }
    
    this.showNotification(message, type)
  }
  
  showNotification(message, type = 'info') {
    // Prevent notification spam
    const now = Date.now()
    this.lastNotification = this.lastNotification || 0
    if (now - this.lastNotification < 1000) return // Reduced to 1 second
    this.lastNotification = now
    
    // Create or get notification container
    let container = document.getElementById('notification-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'notification-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2 pointer-events-none'
      container.style.maxWidth = '384px' // max-w-sm equivalent
      document.body.appendChild(container)
    }
    
    // Create notification element
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
            <button class="inline-flex rounded-md ${bgColor} text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-green-50 focus:ring-green-600" onclick="this.closest('.notification-item').remove()">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    // Add a class for easier removal
    notification.classList.add('notification-item')
    
    // Add to container
    container.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
      notification.classList.add('translate-x-0', 'opacity-100')
    }, 100)
    
    // Auto remove after 4 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.classList.add('translate-x-full', 'opacity-0')
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove()
            
            // Clean up container if empty
            if (container.children.length === 0) {
              container.remove()
            }
          }
        }, 300)
      }
    }, 4000)
  }

  // Handle symbol changes
  symbolValueChanged() {
    console.log(`📊 Symbol changed to: ${this.symbolValue}`)
    if (this.chart && this.candlestickSeries) {
      // Immediately clear all chart data to prevent showing old symbol's data
      console.log(`🧹 Clearing chart data for symbol change to ${this.symbolValue}`)
      this.candlestickSeries.setData([])
      this.ema5Series.setData([])
      this.ema8Series.setData([])
      this.ema22Series.setData([])
      
      // Clear any existing signal markers
      if (this.signalMarkers) {
        this.signalMarkers = []
        this.candlestickSeries.setMarkers([])
      }
      
      // Show loading state immediately
      this.showLoadingState()
      
      // Fetch new data for the selected symbol
      this.fetchImmediateData()
    }
  }
  
  // Fetch immediate market data for the current symbol
  async fetchImmediateData() {
    try {
      console.log(`🔄 Fetching immediate data for ${this.symbolValue} (${this.timeframeValue})...`)
      
      // Show loading state
      this.showLoadingState()
      
      const response = await fetch(`/dashboard/market_data?symbol=${this.symbolValue}&timeframe=${this.timeframeValue}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const result = await response.json()
      
      if (result.success && result.data) {
        console.log(`✅ Received immediate data for ${this.symbolValue}:`, result.data)
        
        // Update chart with real data immediately
        await this.updateChartWithTimeframeData(result.data)
        
        // Hide loading state
        this.hideLoadingState()
      } else {
        throw new Error(result.error || 'Failed to fetch market data')
      }
    } catch (error) {
      console.error(`❌ Error fetching immediate data for ${this.symbolValue}:`, error)
      
      // Always fall back to sample data for the current symbol when fetch fails
        console.log(`🔄 Falling back to sample data for ${this.symbolValue}`)
        this.initializeWithSampleData()
      
      this.hideLoadingState()
    }
  }
  
  // Initialize chart with sample data as fallback
  initializeWithSampleData() {
    if (!this.chart || !this.candlestickSeries) {
      console.warn("Chart not ready for sample data initialization")
      return
    }
    
    try {
      const sampleData = this.generateSampleData()
      
      // Validate sample data before setting
      if (sampleData.candlesticks && sampleData.candlesticks.length > 0) {
        this.candlestickSeries.setData(sampleData.candlesticks)
        console.log(`📊 Initialized ${this.symbolValue} chart with ${sampleData.candlesticks.length} sample candlesticks`)
      }
      
      if (sampleData.ema5 && sampleData.ema5.length > 0) {
        this.ema5Series.setData(sampleData.ema5)
      }
      
      if (sampleData.ema8 && sampleData.ema8.length > 0) {
        this.ema8Series.setData(sampleData.ema8)
      }
      
      if (sampleData.ema22 && sampleData.ema22.length > 0) {
        this.ema22Series.setData(sampleData.ema22)
      }
      
      // Fit content to show all data
      this.chart.timeScale().fitContent()
      
      console.log(`✅ Chart initialized with sample data for ${this.symbolValue}`)
    } catch (error) {
      console.error("Error initializing chart with sample data:", error)
    }
  }
  
  // Show loading state on chart
  showLoadingState() {
    if (this.containerTarget) {
      const loadingOverlay = document.createElement('div')
      loadingOverlay.className = 'absolute inset-0 bg-white bg-opacity-95 flex items-center justify-center z-20'
      loadingOverlay.id = 'chart-loading-overlay'
      loadingOverlay.innerHTML = `
        <div class="text-center">
          <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-500 mx-auto mb-3"></div>
          <p class="text-sm font-medium text-gray-700">Loading ${this.symbolValue} data...</p>
          <p class="text-xs text-gray-500 mt-1">${this.timeframeValue.toUpperCase()} timeframe</p>
        </div>
      `
      
      // Remove existing overlay if present
      const existingOverlay = document.getElementById('chart-loading-overlay')
      if (existingOverlay) {
        existingOverlay.remove()
      }
      
      this.containerTarget.style.position = 'relative'
      this.containerTarget.appendChild(loadingOverlay)
    }
  }
  
  // Hide loading state
  hideLoadingState() {
    const loadingOverlay = document.getElementById('chart-loading-overlay')
    if (loadingOverlay) {
      loadingOverlay.remove()
    }
  }

  // Create simple guaranteed-valid data
  createSimpleValidData(length) {
    const data = []
    const now = Math.floor(Date.now() / 1000)
    
    for (let i = 0; i < length; i++) {
      // Create timestamps in ascending order (older to newer)
      const timestamp = now - ((length - 1 - i) * 5 * 60)
      
      // Create valid OHLC data with slight variations
      const basePrice = 100 + (Math.sin(i / 10) * 2)
      const open = parseFloat(basePrice.toFixed(2))
      const close = parseFloat((basePrice + (Math.random() - 0.5) * 0.5).toFixed(2))
      const high = parseFloat(Math.max(open, close, basePrice + Math.random() * 0.3).toFixed(2))
      const low = parseFloat(Math.min(open, close, basePrice - Math.random() * 0.3).toFixed(2))
      
      data.push({
        time: timestamp,
        open: open,
        high: high,
        low: low,
        close: close
      })
    }
    
    // Sort by time to ensure chronological order
    data.sort((a, b) => a.time - b.time)
    
    console.log(`📊 Created ${data.length} simple valid candlesticks, first: ${JSON.stringify(data[0])}, last: ${JSON.stringify(data[data.length - 1])}`)
    return data
  }

  // Create simple EMA data
  createSimpleEMAData(length, baseValue) {
    const data = []
    const now = Math.floor(Date.now() / 1000)
    
    for (let i = 0; i < length; i++) {
      // Create timestamps in ascending order (older to newer)
      const timestamp = now - ((length - 1 - i) * 5 * 60)
      const value = parseFloat((baseValue + (Math.sin(i / 5) * 0.8)).toFixed(2))
      
      data.push({ 
        time: timestamp, 
        value: value 
      })
    }
    
    // Sort by time to ensure chronological order
    data.sort((a, b) => a.time - b.time)
    
    console.log(`📊 Created ${data.length} simple EMA points, base value: ${baseValue}`)
    return data
  }

  // Enhanced data validation with null checking
  validateChartData(data, dataType = 'candlestick') {
    if (!Array.isArray(data)) {
      console.error(`❌ ${dataType} data is not an array:`, data)
      return []
    }

    const validData = []
    
    for (let i = 0; i < data.length; i++) {
      const item = data[i]
      
      // Check for null/undefined item
      if (!item || typeof item !== 'object') {
        console.warn(`❌ Skipping null/invalid ${dataType} item at index ${i}:`, item)
        continue
      }

      // Validate time
      if (item.time === null || item.time === undefined || typeof item.time !== 'number') {
        console.warn(`❌ Skipping ${dataType} item with invalid time at index ${i}:`, item.time)
        continue
      }

      if (dataType === 'candlestick') {
        // Validate OHLC values
        const { open, high, low, close } = item
        
        if ([open, high, low, close].some(val => val === null || val === undefined || typeof val !== 'number' || isNaN(val))) {
          console.warn(`❌ Skipping candlestick with null/invalid OHLC at index ${i}:`, { open, high, low, close })
          continue
        }

        // Ensure positive values
        if ([open, high, low, close].some(val => val <= 0)) {
          console.warn(`❌ Skipping candlestick with non-positive values at index ${i}:`, { open, high, low, close })
          continue
        }

        // Fix OHLC relationships if needed
        const fixedHigh = Math.max(open, high, low, close)
        const fixedLow = Math.min(open, high, low, close)

        validData.push({
          time: item.time,
          open: parseFloat(open.toFixed(2)),
          high: parseFloat(fixedHigh.toFixed(2)),
          low: parseFloat(fixedLow.toFixed(2)),
          close: parseFloat(close.toFixed(2))
        })
      } else if (dataType === 'line') {
        // Validate line data (EMA)
        const { value } = item
        
        if (value === null || value === undefined || typeof value !== 'number' || isNaN(value) || value <= 0) {
          console.warn(`❌ Skipping line data with invalid value at index ${i}:`, value)
          continue
        }

        validData.push({
          time: item.time,
          value: parseFloat(value.toFixed(2))
        })
      }
    }

    // Sort by time
    validData.sort((a, b) => a.time - b.time)
    
    console.log(`📊 Validated ${dataType} data: ${data.length} input → ${validData.length} valid items`)
    return validData
  }

  // Generate historical data from current market data
  generateHistoricalDataFromCurrent(marketData) {
    console.log(`📊 Generating historical data from current price for ${marketData.symbol} (${this.timeframeValue})`)
    
    const currentPrice = parseFloat(marketData.price) || 100
    const dataPoints = this.getDataPointsForTimeframe()
    const intervalMinutes = this.getIntervalMinutes()
    
    console.log(`📊 Will generate ${dataPoints} data points with ${intervalMinutes}min intervals`)
    
    const candlesticks = []
    const ema5 = []
    const ema8 = []
    const ema22 = []
    
    const now = Math.floor(Date.now() / 1000)
    let basePrice = currentPrice
    
    // Adjust volatility based on timeframe
    let volatilityMultiplier = 1
    switch (this.timeframeValue) {
      case '5m':
        volatilityMultiplier = 0.005  // 0.5% for 5-minute
        break
      case '15m':
        volatilityMultiplier = 0.01   // 1% for 15-minute
        break
      case '1h':
        volatilityMultiplier = 0.02   // 2% for hourly
        break
      case '1d':
        volatilityMultiplier = 0.05   // 5% for daily
        break
      default:
        volatilityMultiplier = 0.01
    }
    
    console.log(`📊 Using volatility multiplier: ${volatilityMultiplier} for ${this.timeframeValue}`)
    
    // Generate historical data working backwards from current time
    for (let i = 0; i < dataPoints; i++) {
      // Create timestamps in ascending order (older to newer)
      const timestamp = now - ((dataPoints - 1 - i) * intervalMinutes * 60)
      
      // Generate realistic price movement around current price
      const movement = (Math.random() - 0.5) * volatilityMultiplier * 2
      
      // For the last data point, use current price
      if (i === dataPoints - 1) {
        basePrice = currentPrice
      } else {
        basePrice = Math.max(1, basePrice * (1 + movement))
      }
      
      const open = basePrice
      const close = i === dataPoints - 1 ? currentPrice : basePrice * (1 + (Math.random() - 0.5) * volatilityMultiplier * 0.5)
      const high = Math.max(open, close) * (1 + Math.random() * volatilityMultiplier * 0.3)
      const low = Math.min(open, close) * (1 - Math.random() * volatilityMultiplier * 0.3)
      
      candlesticks.push({
        time: timestamp,
        open: parseFloat(open.toFixed(2)),
        high: parseFloat(high.toFixed(2)),
        low: parseFloat(low.toFixed(2)),
        close: parseFloat(close.toFixed(2))
      })
      
      // Generate EMA values based on current EMAs if available
      const ema5Value = marketData.emas?.ema5 ? 
        this.interpolateEMA(marketData.emas.ema5, close, i, dataPoints) : 
        close * (1 + Math.sin(i / 5) * volatilityMultiplier * 0.5)
      
      const ema8Value = marketData.emas?.ema8 ? 
        this.interpolateEMA(marketData.emas.ema8, close, i, dataPoints) : 
        close * (1 + Math.sin(i / 8) * volatilityMultiplier * 0.7)
      
      const ema22Value = marketData.emas?.ema22 ? 
        this.interpolateEMA(marketData.emas.ema22, close, i, dataPoints) : 
        close * (1 + Math.sin(i / 22) * volatilityMultiplier * 1.0)
      
      ema5.push({
        time: timestamp,
        value: parseFloat(ema5Value.toFixed(2))
      })
      
      ema8.push({
        time: timestamp,
        value: parseFloat(ema8Value.toFixed(2))
      })
      
      ema22.push({
        time: timestamp,
        value: parseFloat(ema22Value.toFixed(2))
      })
    }
    
    // Sort all arrays by time
    candlesticks.sort((a, b) => a.time - b.time)
    ema5.sort((a, b) => a.time - b.time)
    ema8.sort((a, b) => a.time - b.time)
    ema22.sort((a, b) => a.time - b.time)
    
    console.log(`📊 Generated ${candlesticks.length} historical candlesticks from current price for ${this.timeframeValue}`)
    console.log(`📊 Time range: ${new Date(candlesticks[0]?.time * 1000).toLocaleString()} to ${new Date(candlesticks[candlesticks.length - 1]?.time * 1000).toLocaleString()}`)
    
    return { candlesticks, ema5, ema8, ema22 }
  }

  // Debug method to log current state
  logCurrentState() {
    console.log(`📊 Chart Controller State:`)
    console.log(`   Symbol: ${this.symbolValue}`)
    console.log(`   Timeframe: ${this.timeframeValue}`)
    console.log(`   Data Points: ${this.getDataPointsForTimeframe()}`)
    console.log(`   Interval: ${this.getIntervalMinutes()} minutes`)
    console.log(`   Element: `, this.element)
    console.log(`   Targets: `, this.targets)
  }
}