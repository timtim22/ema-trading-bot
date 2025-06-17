class UnfilledOrderAlertJob < ApplicationJob
  queue_as :default
  
  # Check for orders that have been pending for more than 2 minutes and alert users
  def perform
    Rails.logger.info "UnfilledOrderAlertJob: Starting unfilled order check"
    
    unfilled_positions = Position.unfilled_after_timeout
    
    if unfilled_positions.empty?
      Rails.logger.debug "UnfilledOrderAlertJob: No unfilled orders found"
      return
    end
    
    Rails.logger.info "UnfilledOrderAlertJob: Found #{unfilled_positions.count} unfilled orders"
    
    # Group positions by user for batch notifications
    positions_by_user = unfilled_positions.includes(:user).group_by(&:user)
    
    unfilled_positions.each do |position|
      next unless position.primary_order_id.present?
      
      # Calculate how long the order has been pending
      timeout_duration = (Time.current - position.entry_time).to_i
      
      # Check if we already have an alert for this position/order
      existing_alert = UnfilledOrderAlert.find_by(
        position: position,
        order_id: position.primary_order_id
      )
      
      if existing_alert
        Rails.logger.debug "UnfilledOrderAlertJob: Alert already exists for position #{position.id}"
        next
      end
      
      # Log the unfilled order
      Rails.logger.warn "UnfilledOrderAlertJob: Unfilled order detected - Position #{position.id}, Order #{position.primary_order_id}, Pending for #{timeout_duration}s (#{(timeout_duration/60.0).round(1)}m)"
      
      # Create alert record
      begin
        UnfilledOrderAlert.create!(
          position: position,
          order_id: position.primary_order_id,
          timeout_duration: timeout_duration
        )
        Rails.logger.info "UnfilledOrderAlertJob: Created alert for position #{position.id}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "UnfilledOrderAlertJob: Failed to create alert for position #{position.id}: #{e.message}"
      end
    end
    
    # Send notifications to users
    positions_by_user.each do |user, user_positions|
      next unless user
      
      begin
        UnfilledOrderNotificationService.notify_user(user, user_positions)
        Rails.logger.info "UnfilledOrderAlertJob: Notified user #{user.email} of #{user_positions.count} unfilled orders"
      rescue => e
        Rails.logger.error "UnfilledOrderAlertJob: Failed to notify user #{user.email}: #{e.message}"
      end
    end
    
    Rails.logger.info "UnfilledOrderAlertJob: Completed unfilled order check"
  end
end 