# Configure Sidekiq
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Rails.logger.info "Sidekiq: Configuring Redis connection to #{redis_url.gsub(/\/\/.*@/, '//***@')}"

Sidekiq.configure_server do |config|
  config.redis = { 
    url: redis_url,
    network_timeout: 5,
    pool_timeout: 5
  }
end

Sidekiq.configure_client do |config|
  config.redis = { 
    url: redis_url,
    network_timeout: 5,
    pool_timeout: 5
  }
end

# Test Redis connection on startup
begin
  Sidekiq.redis { |conn| conn.ping }
  Rails.logger.info "Sidekiq: Successfully connected to Redis"
rescue => e
  Rails.logger.error "Sidekiq: Failed to connect to Redis: #{e.message}"
  Rails.logger.error "Sidekiq: REDIS_URL environment variable: #{ENV['REDIS_URL'] ? 'present' : 'missing'}"
  
  # In production, we want to fail fast if Redis is not available
  if Rails.env.production?
    Rails.logger.error "Sidekiq: Redis connection required in production. Application may not function correctly."
  end
end

# Configure Sidekiq-cron for scheduled jobs
require 'sidekiq-cron'

# Load scheduled jobs from config/schedule.yml
if File.exist?(Rails.root.join('config', 'schedule.yml'))
  Rails.application.config.after_initialize do
    schedule_file = Rails.root.join('config', 'schedule.yml')
    if File.exist?(schedule_file)
      schedule = YAML.load_file(schedule_file)
      
      # Only load cron jobs in production or when explicitly enabled
      if Rails.env.production? || ENV['ENABLE_CRON_JOBS'] == 'true'
        Rails.logger.info "Sidekiq-cron: Loading scheduled jobs from #{schedule_file}"
        
        schedule.each do |name, config|
          begin
            Sidekiq::Cron::Job.load_from_hash(name => config)
            Rails.logger.info "Sidekiq-cron: Loaded job '#{name}' with cron '#{config['cron']}'"
          rescue => e
            Rails.logger.error "Sidekiq-cron: Failed to load job '#{name}': #{e.message}"
          end
        end
      else
        Rails.logger.info "Sidekiq-cron: Skipping scheduled jobs in #{Rails.env} environment"
      end
    end
  end
end 