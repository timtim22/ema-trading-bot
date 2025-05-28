// Using standalone version loaded via CDN, no import needed
// The LightweightCharts object is available globally

document.addEventListener('turbo:load', () => {
  const chartContainer = document.getElementById('tradingview-chart');
  if (!chartContainer) return;
  
  initializeChart(chartContainer);
});

function initializeChart(container) {
  // Create the chart
  console.log("🏓 chart.js loaded, looking for #tradingview-chart…");

  const chart = LightweightCharts.createChart(container, {
    layout: {
      background: { color: '#ffffff' },
      textColor: '#333',
    },
    grid: {
      vertLines: { color: '#f0f0f0' },
      horzLines: { color: '#f0f0f0' },
    },
    timeScale: {
      timeVisible: true,
      secondsVisible: false,
    },
  });
  
  // Create a candlestick series using v5.0 API
  const candlestickSeries = chart.addSeries(LightweightCharts.CandlestickSeries, {
    upColor: '#26a69a',
    downColor: '#ef5350',
    borderVisible: false,
    wickUpColor: '#26a69a',
    wickDownColor: '#ef5350',
  });
  
  // Create EMA line series using v5.0 API
  const ema5Series = chart.addSeries(LightweightCharts.LineSeries, {
    color: '#2196F3',
    lineWidth: 2,
    title: 'EMA-5',
  });
  
  const ema8Series = chart.addSeries(LightweightCharts.LineSeries, {
    color: '#FF9800',
    lineWidth: 2,
    title: 'EMA-8',
  });
  
  const ema22Series = chart.addSeries(LightweightCharts.LineSeries, {
    color: '#E91E63',
    lineWidth: 2,
    title: 'EMA-22',
  });
  
  // Sample data for the test chart
  const sampleData = generateSampleData();
  
  // Set the data for each series
  candlestickSeries.setData(sampleData.candlesticks);
  ema5Series.setData(sampleData.ema5);
  ema8Series.setData(sampleData.ema8);
  ema22Series.setData(sampleData.ema22);
  
  // Fit the chart to the data
  chart.timeScale().fitContent();
  
  // Make the chart responsive
  window.addEventListener('resize', () => {
    chart.applyOptions({
      width: container.clientWidth,
    });
  });
}

// Function to generate sample data for testing
function generateSampleData() {
  const candlesticks = [];
  const ema5 = [];
  const ema8 = [];
  const ema22 = [];
  
  // Generate 100 days of sample data
  const now = new Date();
  let basePrice = 100;
  
  for (let i = 0; i < 100; i++) {
    const time = new Date(now);
    time.setDate(time.getDate() - (100 - i));
    
    // Generate a random price movement
    const movement = (Math.random() - 0.5) * 2;
    basePrice = basePrice + movement;
    
    const open = basePrice;
    const high = basePrice + Math.random() * 2;
    const low = basePrice - Math.random() * 2;
    const close = basePrice + (Math.random() - 0.5) * 1.5;
    
    candlesticks.push({
      time: time.getTime() / 1000,
      open,
      high,
      low,
      close
    });
    
    // Simple approximation of EMAs for the sample data
    // In a real app, we'd calculate these properly
    ema5.push({
      time: time.getTime() / 1000,
      value: basePrice + (Math.sin(i / 10) * 1.5)
    });
    
    ema8.push({
      time: time.getTime() / 1000,
      value: basePrice + (Math.sin((i / 15) + 1) * 2)
    });
    
    ema22.push({
      time: time.getTime() / 1000,
      value: basePrice + (Math.sin((i / 25) + 2) * 3)
    });
  }
  
  return { candlesticks, ema5, ema8, ema22 };
} 