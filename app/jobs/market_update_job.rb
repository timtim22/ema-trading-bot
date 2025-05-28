class MarketUpdateJob < ApplicationJob
  queue_as :default

  # This job sends simulated market data updates via ActionCable
  def perform(symbol = "AAPL", simulate_data = false)
    # Send a basic update
    ActionCable.server.broadcast("market_channel", {
      type: "market_update",
      symbol: symbol,
      timestamp: Time.current.to_i,
      message: "Market data update for #{symbol}"
    })
    
    if simulate_data
      # Generate some simulated price data
      current_price = generate_random_price(symbol)
      
      # Broadcast the simulated data
      ActionCable.server.broadcast("market_channel", {
        type: "price_update",
        symbol: symbol,
        price: current_price,
        timestamp: Time.current.to_i
      })
      
      # Also broadcast to the symbol-specific channel
      ActionCable.server.broadcast("market_channel_symbol_#{symbol}", {
        type: "price_update",
        symbol: symbol,
        price: current_price,
        timestamp: Time.current.to_i
      })
    end
    
    # Re-schedule for continuous updates during market hours
    if market_open?
      MarketUpdateJob.set(wait: 30.seconds).perform_later(symbol, simulate_data)
    end
  end
  
  private
  
  # Generate a random price for testing
  def generate_random_price(symbol)
    # Base prices for some common symbols
    base_prices = {
      "AAPL" => 185.5,
      "MSFT" => 402.5,
      "GOOG" => 171.2,
      "AMZN" => 178.3
    }
    
    # Get base price or default
    base = base_prices[symbol] || 100.0
    
    # Add some randomness (±2%)
    change_pct = (rand - 0.5) * 4
    new_price = base * (1 + change_pct / 100.0)
    
    # Format to 2 decimal places
    new_price.round(2)
  end
  
  # Check if market is open (simplified)
  def market_open?
    # For testing, we'll return true
    # In production, implement proper market hours check
    true
  end
end
