class SymbolManagementJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "SymbolManagementJob: Starting symbol management check"
    
    begin
      # Get all active tracked symbols from users
      configured_symbols = User.joins(:tracked_symbols)
                              .where(tracked_symbols: { active: true })
                              .distinct
                              .pluck('tracked_symbols.symbol')
                              .uniq

      Rails.logger.info "SymbolManagementJob: Found configured symbols: #{configured_symbols.join(', ')}"

      # Get currently scheduled cron jobs for market ping
      current_jobs = Sidekiq::Cron::Job.all.select { |job| job.name.start_with?('market_ping_') }
      current_symbols = current_jobs.map { |job| job.name.gsub('market_ping_', '').upcase }

      Rails.logger.info "SymbolManagementJob: Currently scheduled symbols: #{current_symbols.join(', ')}"

      # Add new symbols that aren't currently scheduled
      new_symbols = configured_symbols - current_symbols
      new_symbols.each do |symbol|
        job_name = "market_ping_#{symbol.downcase}"
        cron_expression = "*/30 * * * * *"  # Every 30 seconds
        
        job = Sidekiq::Cron::Job.new(
          name: job_name,
          cron: cron_expression,
          class: 'MarketPingJob',
          args: [symbol]
        )
        
        if job.save
          Rails.logger.info "SymbolManagementJob: Added new scheduled job for #{symbol}"
        else
          Rails.logger.error "SymbolManagementJob: Failed to add job for #{symbol}: #{job.errors}"
        end
      end

      # Remove symbols that are no longer configured
      removed_symbols = current_symbols - configured_symbols
      removed_symbols.each do |symbol|
        job_name = "market_ping_#{symbol.downcase}"
        job = Sidekiq::Cron::Job.find(job_name)
        
        if job&.destroy
          Rails.logger.info "SymbolManagementJob: Removed scheduled job for #{symbol}"
        else
          Rails.logger.error "SymbolManagementJob: Failed to remove job for #{symbol}"
        end
      end

      # Ensure default symbols are always present if no user symbols are configured
      if configured_symbols.empty?
        default_symbols = ['AAPL', 'MSFT']
        default_symbols.each do |symbol|
          job_name = "market_ping_#{symbol.downcase}"
          next if Sidekiq::Cron::Job.find(job_name)
          
          job = Sidekiq::Cron::Job.new(
            name: job_name,
            cron: "*/30 * * * * *",
            class: 'MarketPingJob',
            args: [symbol]
          )
          
          if job.save
            Rails.logger.info "SymbolManagementJob: Added default job for #{symbol}"
          end
        end
      end

      Rails.logger.info "SymbolManagementJob: Symbol management completed successfully"
      
    rescue ActiveRecord::NoDatabaseError
      Rails.logger.warn "SymbolManagementJob: Database not ready, skipping symbol management"
    rescue => e
      Rails.logger.error "SymbolManagementJob: Error during symbol management: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
