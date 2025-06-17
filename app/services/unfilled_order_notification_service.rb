class UnfilledOrderNotificationService
  def self.notify_user(user, unfilled_positions)
    return unless user && unfilled_positions.present?
    
    Rails.logger.info "UnfilledOrderNotificationService: Notifying #{user.email} of #{unfilled_positions.count} unfilled orders"
    
    # Log notification details
    unfilled_positions.each do |position|
      timeout_duration = (Time.current - position.entry_time).to_i
      timeout_minutes = (timeout_duration / 60.0).round(1)
      
      Rails.logger.warn "UnfilledOrderNotificationService: User #{user.email} - Order #{position.primary_order_id} for #{position.symbol} pending #{timeout_minutes}m"
    end
    
    # For now, we'll log the notification
    # In a real application, this could send emails, push notifications, etc.
    message = build_notification_message(user, unfilled_positions)
    Rails.logger.info "UnfilledOrderNotificationService: #{message}"
    
    # Broadcast to user's notifications channel if they're online
    begin
      ActionCable.server.broadcast(
        "notifications_#{user.id}",
        {
          type: 'unfilled_order_alert',
          message: message,
          positions: unfilled_positions.map { |p| position_summary(p) },
          timestamp: Time.current.to_i
        }
      )
    rescue => e
      Rails.logger.error "UnfilledOrderNotificationService: Failed to broadcast to user #{user.id}: #{e.message}"
    end
    
    true
  end
  
  private
  
  def self.build_notification_message(user, positions)
    count = positions.count
    symbols = positions.map(&:symbol).uniq.join(', ')
    
    if count == 1
      position = positions.first
      timeout_minutes = ((Time.current - position.entry_time) / 60.0).round(1)
      "Order for #{position.symbol} has been pending for #{timeout_minutes} minutes (Order ID: #{position.primary_order_id})"
    else
      "#{count} orders have been pending for more than 2 minutes: #{symbols}"
    end
  end
  
  def self.position_summary(position)
    timeout_duration = (Time.current - position.entry_time).to_i
    {
      id: position.id,
      symbol: position.symbol,
      amount: position.amount,
      order_id: position.primary_order_id,
      timeout_duration: timeout_duration,
      timeout_minutes: (timeout_duration / 60.0).round(1),
      entry_time: position.entry_time.iso8601
    }
  end
end 