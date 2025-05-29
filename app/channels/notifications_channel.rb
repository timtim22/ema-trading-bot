class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "NotificationsChannel#subscribed: Subscribing user #{current_user&.email || 'anonymous'}"
    
    # Subscribe to global notifications
    stream_from "notifications_channel"
    
    # Subscribe to user-specific notifications
    if current_user
      stream_from "notifications_channel_user_#{current_user.id}"
    end
    
    # Send initial connection confirmation
    Rails.logger.info "NotificationsChannel#subscribed: Sending connection confirmation"
    transmit({ 
      type: 'connection_established', 
      message: 'Connected to notification updates',
      timestamp: Time.current.to_i
    })
  end
  
  def unsubscribed
    Rails.logger.info "NotificationsChannel#unsubscribed: Connection closed for user #{current_user&.email || 'anonymous'}"
  end
  
  def received(data)
    # Handle any client-side notification requests if needed
    Rails.logger.info "NotificationsChannel#received: #{data}"
  end
end 