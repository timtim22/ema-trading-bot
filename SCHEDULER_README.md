# Scheduler Configuration

This application uses `sidekiq-cron` for automatic job scheduling in production.

## Configuration Files

- `config/schedule.yml` - Defines the scheduled jobs
- `config/initializers/sidekiq.rb` - Configures Sidekiq and loads the scheduler
- `app/jobs/symbol_management_job.rb` - Manages dynamic symbol scheduling

## Scheduled Jobs

### Market Ping Jobs
- **Frequency**: Every 30 seconds
- **Purpose**: Fetch market data and send updates to connected clients
- **Default Symbols**: AAPL, MSFT
- **Dynamic**: Automatically adds/removes jobs based on user-tracked symbols

### Symbol Management Job
- **Frequency**: Every 5 minutes
- **Purpose**: Check for new tracked symbols and manage market ping jobs
- **Function**: Adds jobs for new symbols, removes jobs for unused symbols

## How It Works

1. **Production**: Jobs are automatically loaded from `config/schedule.yml` when the application starts
2. **Development**: Set `ENABLE_CRON_JOBS=true` environment variable to enable scheduling
3. **Dynamic Management**: The `SymbolManagementJob` runs every 5 minutes to:
   - Check for new symbols tracked by users
   - Add new market ping jobs for new symbols
   - Remove jobs for symbols no longer tracked
   - Ensure default symbols (AAPL, MSFT) are always present

## Railway Deployment

The scheduler will automatically work in Railway production environment:
- Sidekiq workers will process the scheduled jobs
- Redis is used for job storage and scheduling
- No manual intervention required

## Monitoring

- Check Sidekiq web UI for job status: `/sidekiq` (if enabled)
- View logs for scheduler activity
- Jobs are logged with `SymbolManagementJob:` and `MarketPingJob:` prefixes

## Environment Variables

- `REDIS_URL` - Redis connection string (automatically set by Railway)
- `ENABLE_CRON_JOBS` - Set to 'true' to enable scheduling in development

## Manual Management

To manually manage scheduled jobs in Rails console:

```ruby
# List all scheduled jobs
Sidekiq::Cron::Job.all

# Add a new job
Sidekiq::Cron::Job.create(
  name: 'market_ping_tsla',
  cron: '*/30 * * * * *',
  class: 'MarketPingJob',
  args: ['TSLA']
)

# Remove a job
Sidekiq::Cron::Job.find('market_ping_tsla')&.destroy
```
