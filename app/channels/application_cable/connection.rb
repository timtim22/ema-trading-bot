module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    
    def connect
      self.current_user = find_verified_user
      Rails.logger.info "ActionCable: User #{current_user.id} connected"
    end
    
    def disconnect
      Rails.logger.info "ActionCable: User #{current_user&.id} disconnected"
    end
    
    private
    
    def find_verified_user
      # Try to find user from session (for web connections)
      if session_user = User.find_by(id: session[:user_id])
        return session_user
      end
      
      # Try to find user from cookies (for Devise)
      if cookies.signed[:user_id]
        if user = User.find_by(id: cookies.signed[:user_id])
          return user
        end
      end
      
      # For development/testing, allow connection without authentication
      if Rails.env.development? || Rails.env.test?
        Rails.logger.warn "ActionCable: No authenticated user found, using first user for development"
        return User.first
      end
      
      # Reject connection if no user found
      Rails.logger.error "ActionCable: No authenticated user found, rejecting connection"
      reject_unauthorized_connection
    end
    
    def session
      @session ||= cookies.encrypted[Rails.application.config.session_options[:key]]
    end
  end
end
