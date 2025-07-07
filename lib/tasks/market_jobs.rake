namespace :market do
  desc "Start market ping jobs for all configured symbols"
  task start_jobs: :environment do
    puts "🚀 Starting MarketPingJobs for all configured symbols..."
    
    begin
      # Get all symbols from users' tracked symbols
      configured_symbols = User.joins(:tracked_symbols)
                               .where(tracked_symbols: { active: true })
                               .distinct
                               .pluck('tracked_symbols.symbol')
      
      if configured_symbols.any?
        puts "📊 Found configured symbols: #{configured_symbols.join(', ')}"
        
        configured_symbols.each do |symbol|
          # Check if bot is running for this symbol
          bot_state = BotState.for_symbol(symbol)
          
          if bot_state.running?
            # Schedule the job
            MarketPingJob.perform_later(symbol)
            puts "✅ Started MarketPingJob for #{symbol}"
          else
            puts "⏸️  Skipping #{symbol} - bot is stopped"
          end
        end
        
        puts "\n🎯 Market ping jobs have been scheduled!"
        puts "💡 Check your dashboard - you should see live market updates soon."
      else
        puts "❌ No active tracked symbols found for any users"
        puts "💡 Users need to configure tracked symbols in the Symbol Management section"
        
        # Fallback to default symbols
        puts "\n🔄 Starting default symbols as fallback..."
        ['AAPL', 'MSFT'].each do |symbol|
          BotState.start!(symbol)
          MarketPingJob.perform_later(symbol)
          puts "✅ Started MarketPingJob for #{symbol} (default)"
        end
      end
      
    rescue => e
      puts "❌ Error starting market jobs: #{e.message}"
      puts "🔄 Trying with default symbols..."
      
      # Emergency fallback
      ['AAPL'].each do |symbol|
        begin
          BotState.start!(symbol)
          MarketPingJob.perform_later(symbol)
          puts "✅ Started MarketPingJob for #{symbol} (emergency fallback)"
        rescue => fallback_error
          puts "❌ Failed to start job for #{symbol}: #{fallback_error.message}"
        end
      end
    end
  end
  
  desc "Stop all market ping jobs"
  task stop_jobs: :environment do
    puts "🛑 Stopping all MarketPingJobs..."
    
    # Stop all bot states
    BotState.update_all(running: false)
    puts "✅ All bot states stopped"
    
    # Clear scheduled jobs (requires Sidekiq)
    begin
      require 'sidekiq/api'
      
      scheduled = Sidekiq::ScheduledSet.new
      market_jobs = scheduled.select do |job|
        job.klass == 'Sidekiq::ActiveJob::Wrapper' && 
        job.args.first['job_class'] == 'MarketPingJob'
      end
      
      market_jobs.each(&:delete)
      puts "✅ Cleared #{market_jobs.count} scheduled MarketPingJobs"
      
    rescue => e
      puts "⚠️  Could not clear scheduled jobs: #{e.message}"
    end
    
    puts "🎯 All market ping jobs have been stopped!"
  end
  
  desc "Check status of market ping jobs"
  task status: :environment do
    puts "📊 Market Ping Jobs Status"
    puts "=" * 40
    
    # Check bot states
    bot_states = BotState.all
    if bot_states.any?
      puts "\n🤖 Bot States:"
      bot_states.each do |state|
        status = state.running? ? "🟢 RUNNING" : "🔴 STOPPED"
        last_run = state.last_run_at ? time_ago_in_words(state.last_run_at) + " ago" : "Never"
        puts "  #{state.symbol}: #{status} (Last run: #{last_run})"
      end
    else
      puts "\n❌ No bot states found"
    end
    
    # Check scheduled jobs
    begin
      require 'sidekiq/api'
      
      scheduled = Sidekiq::ScheduledSet.new
      market_jobs = scheduled.select do |job|
        job.klass == 'Sidekiq::ActiveJob::Wrapper' && 
        job.args.first['job_class'] == 'MarketPingJob'
      end
      
      puts "\n📅 Scheduled MarketPingJobs: #{market_jobs.count}"
      market_jobs.first(5).each do |job|
        symbol = job.args.first['arguments'].first
        scheduled_at = Time.at(job.at).strftime("%H:%M:%S")
        puts "  #{symbol}: scheduled for #{scheduled_at}"
      end
      
      # Check running jobs
      running = Sidekiq::Workers.new
      market_workers = running.select do |process_id, thread_id, work|
        work['payload']['job_class'] == 'MarketPingJob'
      end
      
      puts "\n⚡ Running MarketPingJobs: #{market_workers.count}"
      
    rescue => e
      puts "\n⚠️  Could not check Sidekiq status: #{e.message}"
    end
    
    # Check user symbols
    user_symbols = User.joins(:tracked_symbols)
                      .where(tracked_symbols: { active: true })
                      .distinct
                      .pluck('tracked_symbols.symbol')
    
    puts "\n👥 User Configured Symbols: #{user_symbols.any? ? user_symbols.join(', ') : 'None'}"
    
    puts "\n💡 Tips:"
    puts "  - Run 'rails market:start_jobs' to start jobs"
    puts "  - Run 'rails market:stop_jobs' to stop jobs"
    puts "  - Check your dashboard for live updates"
  end
  
  private
  
  def time_ago_in_words(time)
    distance = Time.current - time
    case distance
    when 0..59
      "#{distance.to_i}s"
    when 60..3599
      "#{(distance / 60).to_i}m"
    else
      "#{(distance / 3600).to_i}h"
    end
  end
end 