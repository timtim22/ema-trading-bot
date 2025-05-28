require 'sidekiq/api'

namespace :sidekiq do
  desc "Clear all Sidekiq queues"
  task clear: :environment do
    Sidekiq::Queue.all.each do |queue|
      puts "Clearing queue #{queue.name} (#{queue.size} jobs)"
      queue.clear
    end
    
    # Clear scheduled jobs
    ss = Sidekiq::ScheduledSet.new
    puts "Clearing scheduled jobs (#{ss.size} jobs)"
    ss.clear
    
    # Clear retry set
    rs = Sidekiq::RetrySet.new
    puts "Clearing retry set (#{rs.size} jobs)"
    rs.clear
    
    # Clear dead set
    ds = Sidekiq::DeadSet.new
    puts "Clearing dead jobs (#{ds.size} jobs)"
    ds.clear
    
    puts "All Sidekiq queues cleared!"
  end
end 