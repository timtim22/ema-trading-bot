# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # Check market hours and show warning if needed
    check_and_warn_market_hours
    
    # Get the default symbol from the user's tracked symbols or use URL param if provided
    user_settings = BotSetting.for_user(current_user)
    # Use the first active tracked symbol, or default to AAPL if no symbols
    default_symbol = current_user.configured_symbols.first || 'AAPL'
    
    @symbol = params[:symbol] || default_symbol
    @timeframe = params[:timeframe] || user_settings.timeframe || '5m'
    @available_symbols = current_user.configured_symbols.presence || ['AAPL']
    @bot_state = BotState.for_symbol(@symbol)
    @all_bot_states = @available_symbols.map { |symbol| BotState.for_symbol(symbol) }
    @positions = Position.open.for_user(current_user).recent_first
    @trading_signals = current_user.recent_trading_signals(10)
  end
  
  def start_bot
    symbols_to_start = current_user.configured_symbols.presence || ['AAPL']
    
    begin
      started_symbols = []
      failed_symbols = []
      
      symbols_to_start.each do |symbol|
        begin
          # Clear any existing scheduled jobs for this symbol to prevent duplicates
          Rails.logger.info "DashboardController: Clearing existing jobs for #{symbol}"
          require 'sidekiq/api'
          Sidekiq::ScheduledSet.new.each do |job|
            if job.klass == 'Sidekiq::ActiveJob::Wrapper' && 
               job.args.first['job_class'] == 'MarketPingJob' && 
               job.args.first['arguments'] == [symbol]
              Rails.logger.info "DashboardController: Removing duplicate job for #{symbol}"
              job.delete
            end
          end
          
          bot_state = BotState.start!(symbol)
          
          # Start the MarketPingJob immediately
          Rails.logger.info "DashboardController: Starting MarketPingJob for #{symbol}"
          job = MarketPingJob.perform_later(symbol)
          Rails.logger.info "DashboardController: Job queued with ID: #{job.job_id} for #{symbol}"
          
          # Log bot start activity
          ActivityLog.log_bot_event(
            'start',
            user: current_user,
            message: "Trading bot started for #{symbol}",
            details: {
              symbol: symbol,
              job_id: job.job_id,
              configured_symbols: symbols_to_start
            }
          )
          
          started_symbols << symbol
        rescue => e
          Rails.logger.error "DashboardController: Failed to start bot for #{symbol}: #{e.message}"
          BotState.log_error!(symbol, e.message)
          
          # Broadcast error notification for this specific symbol
          broadcast_error_notification(
            "Failed to start trading bot for #{symbol}: #{e.message}",
            persistent: true
          )
          
          # Log bot start error
          ActivityLog.log_error(
            "Failed to start trading bot for #{symbol}: #{e.message}",
            context: 'dashboard_controller',
            user: current_user,
            details: {
              symbol: symbol,
              error: e.message,
              backtrace: e.backtrace&.first(5)
            }
          )
          
          failed_symbols << symbol
        end
      end
      
      if failed_symbols.empty?
        # Broadcast success notification
        success_message = "Trading bots started successfully for: #{started_symbols.join(', ')}"
        broadcast_success_notification(success_message)
        
        render json: {
          success: true,
          message: success_message
        }
      else
        # Broadcast warning if some failed
        warning_message = "Some bots failed to start: #{failed_symbols.join(', ')}"
        broadcast_warning_notification(warning_message, persistent: true)
        
        render json: {
          success: false,
          error: warning_message
        }, status: 422
      end
    rescue => e
      # Broadcast error for general failure
      error_message = "Failed to start trading bots: #{e.message}"
      broadcast_error_notification(error_message, persistent: true)
      
      # Log general bot start error
      ActivityLog.log_error(
        error_message,
        context: 'dashboard_controller',
        user: current_user,
        details: {
          symbols: symbols_to_start,
          error: e.message
        }
      )
      
      render json: {
        success: false,
        error: error_message
      }, status: 422
    end
  end
  
  def stop_bot
    symbols_to_stop = current_user.configured_symbols.presence || ['AAPL']
    
    begin
      stopped_symbols = []
      failed_symbols = []
      
      symbols_to_stop.each do |symbol|
        begin
          bot_state = BotState.stop!(symbol)
          
          # Log bot stop activity
          ActivityLog.log_bot_event(
            'stop',
            user: current_user,
            message: "Trading bot stopped for #{symbol}",
            details: {
              symbol: symbol,
              uptime: bot_state.last_run_at ? time_since(bot_state.last_run_at) : 'unknown',
              configured_symbols: symbols_to_stop
            }
          )
          
          stopped_symbols << symbol
        rescue => e
          Rails.logger.error "DashboardController: Failed to stop bot for #{symbol}: #{e.message}"
          
          # Broadcast error notification for this specific symbol
          broadcast_error_notification(
            "Failed to stop trading bot for #{symbol}: #{e.message}",
            persistent: true
          )
          
          # Log bot stop error
          ActivityLog.log_error(
            "Failed to stop trading bot for #{symbol}: #{e.message}",
            context: 'dashboard_controller',
            user: current_user,
            details: {
              symbol: symbol,
              error: e.message
            }
          )
          
          failed_symbols << symbol
        end
      end
      
      if failed_symbols.empty?
        # Broadcast success notification
        success_message = "Trading bots stopped successfully for: #{stopped_symbols.join(', ')}"
        broadcast_success_notification(success_message)
        
        render json: {
          success: true,
          message: success_message
        }
      else
        # Broadcast warning if some failed
        warning_message = "Some bots failed to stop: #{failed_symbols.join(', ')}"
        broadcast_warning_notification(warning_message, persistent: true)
        
        render json: {
          success: false,
          error: warning_message
        }, status: 422
      end
    rescue => e
      # Broadcast error for general failure
      error_message = "Failed to stop trading bots: #{e.message}"
      broadcast_error_notification(error_message, persistent: true)
      
      # Log general bot stop error
      ActivityLog.log_error(
        error_message,
        context: 'dashboard_controller',
        user: current_user,
        details: {
          symbols: symbols_to_stop,
          error: e.message
        }
      )
      
      render json: {
        success: false,
        error: error_message
      }, status: 422
    end
  end
  
  def bot_status
    default_symbol = current_user.configured_symbols.first || 'AAPL'
    symbol = params[:symbol] || default_symbol
    
    bot_state = BotState.for_symbol(symbol)
    
    render json: {
      running: bot_state.running?,
      status: bot_state.status_text,
      last_run: bot_state.last_run_display,
      error_message: bot_state.error_message,
      symbol: bot_state.symbol
    }
  end
  
  def market_data
    symbol = params[:symbol]
    timeframe = params[:timeframe] || '5m'
    
    # Check if user has access to this symbol
    unless current_user.configured_symbols.include?(symbol)
      broadcast_error_notification("Symbol #{symbol} not configured for your account")
      render json: { error: 'Symbol not configured for this user' }, status: 403
      return
    end
    
    begin
      # Check market hours and show warning if needed
      check_and_warn_market_hours
      
      # Get current market data using the same service as MarketPingJob
      price_data = MarketDataService.get_current_price(symbol)
      ohlc_data = MarketDataService.get_ohlc_data(symbol)
      
      # Get historical data based on timeframe
      historical_data = get_historical_data_for_timeframe(symbol, timeframe)
      
      market_data = {
        symbol: symbol,
        timeframe: timeframe,
        price: price_data[:price],
        ohlc: {
          open: ohlc_data[:open],
          high: ohlc_data[:high],
          low: ohlc_data[:low],
          close: ohlc_data[:close]
        },
        emas: historical_data[:emas],
        volume: ohlc_data[:volume],
        source: price_data[:source],
        timestamp: Time.current.to_i,
        historical_candles: historical_data[:candles]
      }
      
      render json: {
        success: true,
        data: market_data
      }
    rescue => e
      Rails.logger.error "DashboardController#market_data: Error fetching data for #{symbol}: #{e.message}"
      
      # Broadcast data unavailable warning
      broadcast_data_unavailable_warning(symbol: symbol)
      
      render json: { 
        success: false, 
        error: 'Failed to fetch market data',
        message: e.message 
      }, status: 500
    end
  end
  
  private
  
  # Calculate EMAs from closing prices (same logic as MarketPingJob)
  def calculate_emas_from_closes(closes)
    return { ema5: 0, ema8: 0, ema22: 0 } if closes.empty?
    
    ema5 = calculate_ema(closes, 5)
    ema8 = calculate_ema(closes, 8)
    ema22 = calculate_ema(closes, 22)
    
    {
      ema5: ema5.round(2),
      ema8: ema8.round(2),
      ema22: ema22.round(2)
    }
  end
  
  def calculate_ema(prices, period)
    return 0 if prices.empty?
    return prices.last if prices.length == 1
    
    multiplier = 2.0 / (period + 1)
    
    if prices.length < period
      return prices.sum / prices.length
    end
    
    ema = prices.first(period).sum / period
    
    prices.drop(period).each do |price|
      ema = (price * multiplier) + (ema * (1 - multiplier))
    end
    
    ema
  end
  
  # Get historical data for different timeframes
  def get_historical_data_for_timeframe(symbol, timeframe)
    case timeframe
    when '5m'
      limit = 288 # 24 hours of 5-minute candles (24 * 60 / 5 = 288)
      closes_limit = 50
    when '15m'
      limit = 96  # 24 hours of 15-minute candles (24 * 60 / 15 = 96)
      closes_limit = 50
    when '1h'
      limit = 168 # 7 days of hourly candles (7 * 24 = 168)
      closes_limit = 50
    when '1d'
      limit = 90  # 90 days of daily candles
      closes_limit = 50
    else
      limit = 100
      closes_limit = 50
    end
    
    Rails.logger.info "DashboardController: Generating #{limit} candles for #{symbol} (#{timeframe})"
    
    begin
      # For now, we'll generate realistic historical data
      # In a full implementation, you'd fetch from Alpaca's historical API
      current_price_data = MarketDataService.get_current_price(symbol)
      current_price = current_price_data[:price]
      
      candles = generate_historical_candles(current_price, limit, timeframe)
      closes = candles.map { |c| c[:close] }
      emas = calculate_emas_from_closes(closes)
      
      Rails.logger.info "DashboardController: Generated #{candles.length} candles for #{symbol} (#{timeframe})"
      
      {
        candles: candles,
        emas: emas
      }
    rescue => e
      Rails.logger.error "Error getting historical data: #{e.message}"
      # Fallback to simple data
      {
        candles: [],
        emas: { ema5: 0, ema8: 0, ema22: 0 }
      }
    end
  end
  
  # Generate realistic historical candles for different timeframes
  def generate_historical_candles(current_price, limit, timeframe)
    candles = []
    base_price = current_price
    
    # Calculate time intervals
    interval_minutes = case timeframe
    when '5m' then 5
    when '15m' then 15
    when '1h' then 60
    when '1d' then 1440
    else 5
    end
    
    current_time = Time.current.to_i
    
    # Generate historical candles working backwards
    (0...limit).reverse_each do |i|
      time = current_time - (i * interval_minutes * 60)
      
      # Generate price variation (more for longer timeframes)
      volatility = case timeframe
      when '5m' then 0.002  # 0.2%
      when '15m' then 0.005 # 0.5%
      when '1h' then 0.01   # 1%
      when '1d' then 0.03   # 3%
      else 0.002
      end
      
      # Random walk with mean reversion
      change = (rand - 0.5) * volatility * 2
      if i == 0
        # Last candle should end at current price
        close = current_price
        open = close * (1 - change)
      else
        open = base_price
        close = open * (1 + change)
      end
      
      high = [open, close].max * (1 + rand * volatility)
      low = [open, close].min * (1 - rand * volatility)
      
      candles << {
        time: time,
        open: open.round(2),
        high: high.round(2),
        low: low.round(2),
        close: close.round(2),
        volume: (500_000 + rand * 1_000_000).to_i
      }
      
      base_price = close
    end
    
    candles.reverse
  end
  
  def time_since(time)
    distance = Time.current - time
    case distance
    when 0..59
      "#{distance.to_i} seconds"
    when 60..3599
      "#{(distance / 60).to_i} minutes"
    else
      "#{(distance / 3600).to_i} hours"
    end
  end
end 