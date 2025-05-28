# Schedule market update jobs in development and production environments
if Rails.env.development? || Rails.env.production?
  Rails.application.config.after_initialize do
    # Only run in the actual app process, not during asset compilation, etc.
    if defined?(Rails::Server)
      Rails.logger.info "Scheduling initial market ping jobs for Sidekiq"
      
      # Use our new MarketPingJob which will reschedule itself
      MarketPingJob.perform_later("AAPL")
      MarketPingJob.perform_later("MSFT")
    end
  end
end 