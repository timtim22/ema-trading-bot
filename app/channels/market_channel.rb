class MarketChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "MarketChannel#subscribed: Subscribing user #{current_user&.email || 'anonymous'}"
    stream_from "market_channel"
    stream_from "market_channel_#{current_user.id}" if current_user
    
    # Send initial connection confirmation
    Rails.logger.info "MarketChannel#subscribed: Sending connection confirmation"
    transmit({ type: 'connection_established', message: 'Connected to market updates' })
  end
  
  def unsubscribed
    # Clean up when connection is closed
    Rails.logger.info "MarketChannel#unsubscribed: Connection closed"
  end
  
  # Method to subscribe to a specific symbol
  def follow(data)
    symbol = data['symbol']
    return if symbol.blank?
    
    Rails.logger.info "MarketChannel#follow: Following symbol #{symbol}"
    
    # Stream from symbol-specific channel
    stream_from "market_channel_symbol_#{symbol}"
    
    # Confirm subscription
    transmit({ type: 'following_symbol', symbol: symbol })
  end
end
