class CheckOrderStatusJob < ApplicationJob
  queue_as :default
  
  # Monitor a pending order and update position status when filled
  # 
  # @param position_id [Integer] the Position record ID to monitor
  # @param order_id [String] the Alpaca order ID to check
  def perform(position_id, order_id)
    position = Position.find(position_id)
    
    unless position
      Rails.logger.error "CheckOrderStatusJob: Position not found with ID #{position_id}"
      return
    end
    
    # Only monitor pending positions
    unless position.status == 'pending'
      Rails.logger.info "CheckOrderStatusJob: Position #{position_id} is no longer pending (#{position.status}), stopping monitoring"
      return
    end
    
    # Get current order status from Alpaca
    order_service = OrderService.new
    current_order = order_service.get_order_status(order_id)
    
    unless current_order
      Rails.logger.error "CheckOrderStatusJob: Failed to check order status for #{order_id}: #{order_service.last_error}"
      # Reschedule to try again in 30 seconds
      CheckOrderStatusJob.set(wait: 30.seconds).perform_later(position_id, order_id)
      return
    end
    
    Rails.logger.info "CheckOrderStatusJob: Order #{order_id} status: #{current_order.status}"
    
    case current_order.status
    when 'filled'
      # Order is filled - update position with fill data
      fill_price = current_order.filled_avg_price.to_f
      fill_qty = current_order.filled_qty.to_f
      
      position.update!(
        status: 'open',
        entry_price: fill_price,
        fill_qty: fill_qty,
        fill_notional: fill_qty * fill_price
      )
      
      Rails.logger.info "CheckOrderStatusJob: Position #{position_id} filled at $#{fill_price} for #{fill_qty} shares"
      
      # Create safety orders for the filled position
      begin
        order_service.setup_safety_orders(
          position.symbol,
          current_order,
          get_profit_percentage(position),
          get_loss_percentage(position)
        )
        Rails.logger.info "CheckOrderStatusJob: Safety orders created for position #{position_id}"
      rescue => e
        Rails.logger.error "CheckOrderStatusJob: Failed to create safety orders for position #{position_id}: #{e.message}"
      end
      
      # No need to reschedule - order is complete
      
    when 'cancelled', 'rejected', 'expired'
      # Order failed - update position status
      position.update!(status: 'cancelled')
      Rails.logger.warn "CheckOrderStatusJob: Order #{order_id} was #{current_order.status}, position #{position_id} marked as cancelled"
      
      # No need to reschedule - order is complete
      
    when 'pending', 'new', 'partially_filled', 'accepted'
      # Order still pending - reschedule check in 30 seconds
      CheckOrderStatusJob.set(wait: 30.seconds).perform_later(position_id, order_id)
      Rails.logger.debug "CheckOrderStatusJob: Order #{order_id} still #{current_order.status}, rescheduling check"
      
    else
      Rails.logger.warn "CheckOrderStatusJob: Unknown order status '#{current_order.status}' for order #{order_id}"
      # Reschedule to check again
      CheckOrderStatusJob.set(wait: 30.seconds).perform_later(position_id, order_id)
    end
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "CheckOrderStatusJob: Position not found with ID #{position_id}"
  rescue => e
    Rails.logger.error "CheckOrderStatusJob: Error monitoring order #{order_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Reschedule one more time on error
    CheckOrderStatusJob.set(wait: 60.seconds).perform_later(position_id, order_id)
  end
  
  private
  
  # Get profit percentage for the position's user or default
  def get_profit_percentage(position)
    if position.user&.bot_setting
      position.user.bot_setting.profit_percentage
    else
      ENV.fetch("PROFIT_PERCENTAGE", "1").to_f
    end
  end
  
  # Get loss percentage for the position's user or default
  def get_loss_percentage(position)
    if position.user&.bot_setting
      position.user.bot_setting.loss_percentage
    else
      ENV.fetch("LOSS_PERCENTAGE", "1").to_f
    end
  end
end 