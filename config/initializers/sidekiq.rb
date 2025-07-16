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