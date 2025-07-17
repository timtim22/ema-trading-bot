# Schedule market update jobs in development and production environments
if Rails.env.development? || Rails.env.production?
  Rails.application.config.after_initialize do
    # Market update jobs are now scheduled automatically using sidekiq-cron
    # See config/schedule.yml for the cron job configuration
    # Jobs will run automatically in production via sidekiq-cron

    # Note: Manual job scheduling has been replaced with automatic scheduling
    # The MarketPingJob will be triggered by sidekiq-cron based on the schedule.yml configuration
    # This ensures consistent job execution in production without manual intervention

    Rails.logger.info "Market updates: Using sidekiq-cron for automatic job scheduling"
  end
end