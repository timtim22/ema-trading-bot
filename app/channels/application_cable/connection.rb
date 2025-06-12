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
      if session.present? && session[:user_id]
        if session_user = User.find_by(id: session[:user_id])
          return session_user
        end
      end

      # Try to find user from cookies (for Devise)
      if cookies.signed[:user_id]
        if user = User.find_by(id: cookies.signed[:user_id])
          return user
        end
      end

      # Try to find user from Devise warden session
      if cookies.encrypted.present?
        devise_session = cookies.encrypted["_ema_trading_bot_session"]
        if devise_session.present? && devise_session["warden.user.user.key"].present?
          user_id = devise_session["warden.user.user.key"][0][0]
          if user = User.find_by(id: user_id)
            return user
          end
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
      @session ||= begin
        session_key = Rails.application.config.session_options[:key]
        cookies.encrypted[session_key] if session_key && cookies.encrypted[session_key]
      end
    end
  end
end
