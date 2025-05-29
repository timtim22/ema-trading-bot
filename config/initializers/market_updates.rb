# Schedule market update jobs in development and production environments
if Rails.env.development? || Rails.env.production?
  Rails.application.config.after_initialize do
    # Only run in the actual app process, not during asset compilation, etc.
    if defined?(Rails::Server)
      Rails.logger.info "Scheduling initial market ping jobs for Sidekiq"
      
      # Start jobs for all symbols that users have configured
      begin
        configured_symbols = User.joins(:tracked_symbols)
                                .where(tracked_symbols: { active: true })
                                .distinct
                                .pluck('tracked_symbols.symbol')
        
        if configured_symbols.any?
          Rails.logger.info "Starting MarketPingJob for configured symbols: #{configured_symbols.join(', ')}"
          configured_symbols.each do |symbol|
            MarketPingJob.perform_later(symbol)
            Rails.logger.info "Scheduled MarketPingJob for #{symbol}"
          end
        else
          # Fallback to default symbols if no users have configured symbols yet
          Rails.logger.info "No configured symbols found, starting default symbols"
          MarketPingJob.perform_later("AAPL")
          MarketPingJob.perform_later("MSFT")
        end
      rescue => e
        Rails.logger.error "Error scheduling market ping jobs: #{e.message}"
        # Fallback to default symbols
        Rails.logger.info "Falling back to default symbols due to error"
      MarketPingJob.perform_later("AAPL")
      MarketPingJob.perform_later("MSFT")
      end
    end
  end
end 