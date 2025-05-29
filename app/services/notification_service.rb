class NotificationService
  class << self
    # Broadcast error notifications
    def broadcast_error(message, user: nil, persistent: false, context: nil)
      data = {
        type: 'error',
        message: message,
        persistent: persistent,
        context: context,
        timestamp: Time.current.to_i
      }
      
      if user
        ActionCable.server.broadcast("notifications_channel_user_#{user.id}", data)
      else
        ActionCable.server.broadcast("notifications_channel", data)
      end
      
      Rails.logger.info "NotificationService: Broadcasted error - #{message}"
    end
    
    # Broadcast warning notifications
    def broadcast_warning(message, user: nil, persistent: false, warning_key: nil)
      data = {
        type: 'warning',
        message: message,
        persistent: persistent,
        warning_key: warning_key,
        timestamp: Time.current.to_i
      }
      
      if user
        ActionCable.server.broadcast("notifications_channel_user_#{user.id}", data)
      else
        ActionCable.server.broadcast("notifications_channel", data)
      end
      
      Rails.logger.info "NotificationService: Broadcasted warning - #{message}"
    end
    
    # Broadcast success notifications
    def broadcast_success(message, user: nil, persistent: false)
      data = {
        type: 'success',
        message: message,
        persistent: persistent,
        timestamp: Time.current.to_i
      }
      
      if user
        ActionCable.server.broadcast("notifications_channel_user_#{user.id}", data)
      else
        ActionCable.server.broadcast("notifications_channel", data)
      end
      
      Rails.logger.info "NotificationService: Broadcasted success - #{message}"
    end
    
    # Broadcast info notifications
    def broadcast_info(message, user: nil, persistent: false)
      data = {
        type: 'info',
        message: message,
        persistent: persistent,
        timestamp: Time.current.to_i
      }
      
      if user
        ActionCable.server.broadcast("notifications_channel_user_#{user.id}", data)
      else
        ActionCable.server.broadcast("notifications_channel", data)
      end
      
      Rails.logger.info "NotificationService: Broadcasted info - #{message}"
    end
    
    # Specific warning for market hours
    def broadcast_market_hours_warning(user: nil)
      data = {
        type: 'market_hours_warning',
        message: 'Outside market hours - live data may be limited',
        persistent: false,
        warning_key: "market_hours_#{Date.current.strftime('%Y%m%d')}",
        timestamp: Time.current.to_i
      }
      
      if user
        ActionCable.server.broadcast("notifications_channel_user_#{user.id}", data)
      else
        ActionCable.server.broadcast("notifications_channel", data)
      end
      
      Rails.logger.info "NotificationService: Broadcasted market hours warning"
    end
    
    # Specific warning for data unavailability
    def broadcast_data_unavailable_warning(symbol: nil, user: nil)
      message = symbol ? "Market data for #{symbol} temporarily unavailable" : "Market data temporarily unavailable"
      
      data = {
        type: 'data_unavailable_warning',
        message: message,
        symbol: symbol,
        persistent: false,
        warning_key: "data_unavailable_#{symbol || 'general'}",
        timestamp: Time.current.to_i
      }
      
      if user
        ActionCable.server.broadcast("notifications_channel_user_#{user.id}", data)
      else
        ActionCable.server.broadcast("notifications_channel", data)
      end
      
      Rails.logger.info "NotificationService: Broadcasted data unavailable warning for #{symbol || 'general'}"
    end
    
    # Check if currently outside market hours
    def outside_market_hours?
      now = Time.current.in_time_zone("America/New_York")
      
      # Check if it's a weekend
      return true if now.saturday? || now.sunday?
      
      # Market hours: 9:30 AM to 4:00 PM ET
      market_open = now.beginning_of_day + 9.hours + 30.minutes
      market_close = now.beginning_of_day + 16.hours
      
      now < market_open || now > market_close
    end
    
    # Check and broadcast market hours warning if needed
    def check_and_broadcast_market_hours_warning(user: nil)
      if outside_market_hours?
        broadcast_market_hours_warning(user: user)
        true
      else
        false
      end
    end
  end
end 