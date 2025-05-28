class TradingSignalsChannel < ApplicationCable::Channel
  def subscribed
    # Authenticate user
    return reject unless current_user
    
    user_id = params[:user_id]
    
    # Ensure user can only subscribe to their own signals
    if current_user.id != user_id.to_i
      Rails.logger.warn "TradingSignalsChannel: User #{current_user.id} tried to subscribe to user #{user_id} signals"
      return reject
    end
    
    # Subscribe to user-specific trading signals stream
    stream_name = "trading_signals_user_#{user_id}"
    stream_from stream_name
    
    Rails.logger.info "TradingSignalsChannel: User #{current_user.id} subscribed to #{stream_name}"
  end

  def unsubscribed
    Rails.logger.info "TradingSignalsChannel: User #{current_user&.id} unsubscribed"
    # Any cleanup needed when channel is unsubscribed
  end
  
  def receive(data)
    # Handle any incoming data from client if needed
    Rails.logger.debug "TradingSignalsChannel: Received data from user #{current_user&.id}: #{data}"
  end
end
