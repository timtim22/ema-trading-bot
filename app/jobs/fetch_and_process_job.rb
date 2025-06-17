# frozen_string_literal: true

# Job to fetch market data and process EMA calculations on a recurring schedule
# The polling interval is controlled by the POLL_INTERVAL environment variable
class FetchAndProcessJob < ApplicationJob
  queue_as :default

  # Generate cron schedule based on POLL_INTERVAL environment variable
  #
  # @param interval [String] The polling interval (e.g., "1Min", "5Min", "15Min")
  # @return [String] The cron expression for the given interval
  def self.cron_schedule_for_interval(interval)
    case interval.to_s.downcase
    when "1min", "1m"
      "*/1 * * * *"  # Every minute
    when "5min", "5m"
      "*/5 * * * *"  # Every 5 minutes
    when "15min", "15m"
      "*/15 * * * *" # Every 15 minutes
    when "30min", "30m"
      "*/30 * * * *" # Every 30 minutes
    when "1hour", "1h", "60min"
      "0 * * * *"    # Every hour
    else
      "*/5 * * * *"  # Default to every 5 minutes
    end
  end

  # Get the current polling interval from environment
  #
  # @return [String] The polling interval
  def self.current_interval
    ENV.fetch("POLL_INTERVAL", "5Min")
  end

  # Get the current cron schedule based on POLL_INTERVAL
  #
  # @return [String] The cron expression
  def self.current_cron_schedule
    cron_schedule_for_interval(current_interval)
  end

  # Check if the current schedule matches the configuration
  #
  # @return [Boolean] Whether schedule needs updating
  def self.schedule_needs_update?
    # This would check if the current recurring task schedule matches POLL_INTERVAL
    # In a real implementation, this would check SolidQueue recurring tasks
    true
  end

  # Update the recurring task schedule based on current POLL_INTERVAL
  def self.update_schedule!
    return unless defined?(SolidQueue)

    current_schedule = current_cron_schedule
    Rails.logger.info "FetchAndProcessJob: Updating schedule to #{current_schedule} (#{current_interval})"

    # Remove existing recurring task if it exists
    if SolidQueue::RecurringTask.exists?(key: "fetch_and_process")
      SolidQueue::RecurringTask.find_by(key: "fetch_and_process").destroy
    end

    # Create new recurring task with updated schedule
    SolidQueue::RecurringTask.create!(
      key: "fetch_and_process",
      schedule: current_schedule,
      class_name: "FetchAndProcessJob",
      static: false,
      description: "Fetch market data and process EMAs every #{current_interval}"
    )

    Rails.logger.info "FetchAndProcessJob: Schedule updated successfully"
  rescue => e
    Rails.logger.error "FetchAndProcessJob: Failed to update schedule - #{e.message}"
    false
  end

  def perform
    Rails.logger.info "FetchAndProcessJob: Starting data fetch and processing (interval: #{self.class.current_interval})"
    
    start_time = Time.current
    processed_symbols = []
    failed_symbols = []

    begin
      # Get all active tracked symbols from users
      symbols = get_active_symbols
      
      if symbols.empty?
        Rails.logger.warn "FetchAndProcessJob: No active symbols to process"
        return
      end

      Rails.logger.info "FetchAndProcessJob: Processing #{symbols.length} symbols: #{symbols.join(', ')}"

      # Process each symbol
      symbols.each do |symbol|
        begin
          process_symbol(symbol)
          processed_symbols << symbol
          Rails.logger.debug "FetchAndProcessJob: Successfully processed #{symbol}"
        rescue => e
          failed_symbols << symbol
          Rails.logger.error "FetchAndProcessJob: Failed to process #{symbol} - #{e.message}"
        end
      end

      duration = (Time.current - start_time).round(2)
      Rails.logger.info "FetchAndProcessJob: Completed in #{duration}s - Success: #{processed_symbols.length}, Failed: #{failed_symbols.length}"

      # Log summary
      if failed_symbols.any?
        Rails.logger.warn "FetchAndProcessJob: Failed symbols: #{failed_symbols.join(', ')}"
      end

    rescue => e
      Rails.logger.error "FetchAndProcessJob: Fatal error during processing - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  # Get all active symbols that should be processed
  #
  # @return [Array<String>] Array of symbol strings
  def get_active_symbols
    symbols = []

    # Get symbols from user configurations
    if defined?(User) && User.respond_to?(:joins)
      begin
        user_symbols = User.joins(:tracked_symbols)
                          .where(tracked_symbols: { active: true })
                          .distinct
                          .pluck('tracked_symbols.symbol')
        symbols.concat(user_symbols)
      rescue => e
        Rails.logger.warn "FetchAndProcessJob: Could not fetch user symbols - #{e.message}"
      end
    end

    # Get symbols from bot states
    if defined?(BotState)
      begin
        bot_symbols = BotState.where(running: true).pluck(:symbol)
        symbols.concat(bot_symbols)
      rescue => e
        Rails.logger.warn "FetchAndProcessJob: Could not fetch bot state symbols - #{e.message}"
      end
    end

    # Fallback to environment variable
    if symbols.empty?
      env_symbols = ENV.fetch("WATCH_SYMBOLS", "AAPL,MSFT").split(',').map(&:strip)
      symbols.concat(env_symbols)
      Rails.logger.info "FetchAndProcessJob: Using fallback symbols from ENV: #{symbols.join(', ')}"
    end

    symbols.uniq.reject(&:blank?)
  end

  # Process a single symbol: fetch data and calculate EMAs
  #
  # @param symbol [String] The stock symbol to process
  def process_symbol(symbol)
    # Use TradingBotService to fetch and process data
    # Get a default user for the service (or nil)
    default_user = nil
    if defined?(User) && User.respond_to?(:first)
      default_user = User.first
    end

    # Initialize trading bot service
    timeframe = ENV.fetch("DEFAULT_TIMEFRAME", "5m")
    trading_bot = TradingBotService.new(symbol, timeframe, default_user)

    # Run the trading bot logic (fetch data, calculate EMAs, save readings)
    # Use async: false to prevent infinite job spawning
    success = trading_bot.run(async: false)

    unless success
      error_message = trading_bot.last_error || "Unknown error"
      raise StandardError, "TradingBotService failed: #{error_message}"
    end

    Rails.logger.debug "FetchAndProcessJob: Successfully processed #{symbol} with #{timeframe} timeframe"
  end
end 