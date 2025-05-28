namespace :bot do
  desc "Stop all MarketPingJob instances"
  task stop_all: :environment do
    puts "🛑 Stopping all MarketPingJob instances..."
    
    require 'sidekiq/api'
    
    # Stop scheduled jobs
    scheduled_count = 0
    Sidekiq::ScheduledSet.new.each do |job|
      if job.klass == 'Sidekiq::ActiveJob::Wrapper' && 
         job.args.first['job_class'] == 'MarketPingJob'
        symbol = job.args.first['arguments'].first
        puts "  🗑️  Removing scheduled job for #{symbol}"
        job.delete
        scheduled_count += 1
      end
    end
    
    # Stop retry jobs
    retry_count = 0
    Sidekiq::RetrySet.new.each do |job|
      if job.klass == 'Sidekiq::ActiveJob::Wrapper' && 
         job.args.first['job_class'] == 'MarketPingJob'
        symbol = job.args.first['arguments'].first
        puts "  🗑️  Removing retry job for #{symbol}"
        job.delete
        retry_count += 1
      end
    end
    
    # Stop all bot states
    BotState.update_all(running: false)
    puts "  🔄 Set all bot states to stopped"
    
    puts "✅ Cleanup complete:"
    puts "   - Removed #{scheduled_count} scheduled jobs"
    puts "   - Removed #{retry_count} retry jobs"
    puts "   - Stopped all bot states"
  end
  
  desc "Start bots for configured symbols"
  task start_configured: :environment do
    puts "🚀 Starting bots for configured symbols..."
    
    User.find_each do |user|
      settings = BotSetting.for_user(user)
      symbols = settings.symbols_list
      
      if symbols.any?
        puts "👤 User #{user.email}: Starting bots for #{symbols.join(', ')}"
        
        symbols.each do |symbol|
          begin
            bot_state = BotState.start!(symbol)
            job = MarketPingJob.perform_later(symbol)
            puts "  ✅ Started #{symbol} - Job ID: #{job.job_id}"
          rescue => e
            puts "  ❌ Failed to start #{symbol}: #{e.message}"
          end
        end
      else
        puts "👤 User #{user.email}: No symbols configured"
      end
    end
    
    puts "🎉 Bot startup complete!"
  end
  
  desc "Restart all bots (stop all + start configured)"
  task restart: :environment do
    Rake::Task['bot:stop_all'].invoke
    puts ""
    Rake::Task['bot:start_configured'].invoke
  end
  
  desc "Show current bot status"
  task status: :environment do
    puts "📊 Current Bot Status:"
    puts ""
    
    # Show Sidekiq jobs
    require 'sidekiq/api'
    scheduled_jobs = Sidekiq::ScheduledSet.new.select do |job|
      job.klass == 'Sidekiq::ActiveJob::Wrapper' && 
      job.args.first['job_class'] == 'MarketPingJob'
    end
    
    puts "🕐 Scheduled MarketPingJob instances: #{scheduled_jobs.count}"
    scheduled_jobs.each do |job|
      symbol = job.args.first['arguments'].first
      puts "   - #{symbol} (scheduled for #{job.at})"
    end
    
    puts ""
    
    # Show bot states
    bot_states = BotState.all
    puts "🤖 Bot States:"
    if bot_states.any?
      bot_states.each do |state|
        status = state.running? ? "🟢 RUNNING" : "🔴 STOPPED"
        puts "   - #{state.symbol}: #{status} (last run: #{state.last_run_display})"
      end
    else
      puts "   No bot states found"
    end
    
    puts ""
    
    # Show user configurations
    puts "⚙️  User Configurations:"
    User.find_each do |user|
      settings = BotSetting.for_user(user)
      puts "   - #{user.email}: #{settings.symbols_list.join(', ')}"
    end
  end
end 