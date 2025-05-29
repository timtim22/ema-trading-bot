module NotificationsHelper
  # Helper methods for broadcasting notifications from controllers
  
  def broadcast_error_notification(message, persistent: false, context: nil)
    NotificationService.broadcast_error(
      message, 
      user: current_user, 
      persistent: persistent, 
      context: context
    )
  end
  
  def broadcast_warning_notification(message, persistent: false, warning_key: nil)
    NotificationService.broadcast_warning(
      message, 
      user: current_user, 
      persistent: persistent, 
      warning_key: warning_key
    )
  end
  
  def broadcast_success_notification(message, persistent: false)
    NotificationService.broadcast_success(
      message, 
      user: current_user, 
      persistent: persistent
    )
  end
  
  def broadcast_info_notification(message, persistent: false)
    NotificationService.broadcast_info(
      message, 
      user: current_user, 
      persistent: persistent
    )
  end
  
  # Specific helper for market hours warnings
  def check_and_warn_market_hours
    NotificationService.check_and_broadcast_market_hours_warning(user: current_user)
  end
  
  # Helper for data unavailable warnings
  def broadcast_data_unavailable_warning(symbol: nil)
    NotificationService.broadcast_data_unavailable_warning(
      symbol: symbol, 
      user: current_user
    )
  end
  
  # Render JSON with success notification
  def render_json_with_success(data, message)
    broadcast_success_notification(message)
    render json: data.merge(success: true, message: message)
  end
  
  # Render JSON with error notification
  def render_json_with_error(message, status: 422)
    broadcast_error_notification(message)
    render json: { success: false, error: message }, status: status
  end
  
  # Handle exceptions with notifications
  def handle_exception_with_notification(exception, context: nil, user_message: nil)
    error_message = user_message || "An error occurred: #{exception.message}"
    
    broadcast_error_notification(
      error_message,
      persistent: true,
      context: context
    )
    
    # Log the full exception
    Rails.logger.error "Exception in #{context}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
  end
end 