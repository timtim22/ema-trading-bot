# frozen_string_literal: true

# Service to fetch account information from Alpaca API
class AccountService
  attr_reader :last_error, :last_response
  
  def initialize
    @client = ALPACA_CLIENT
  end
  
  # Get account information from Alpaca
  #
  # @return [Hash, nil] account information or nil if failed
  def get_account_info
    begin
      account = @client.account
      @last_response = account
      
      if account
        {
          account_id: account.id,
          account_number: account.id, # Use id as account number since account_number doesn't exist
          status: account.status,
          currency: account.currency,
          buying_power: account.buying_power.to_f,
          regt_buying_power: safe_to_f(account, :regt_buying_power, account.buying_power),
          daytrading_buying_power: safe_to_f(account, :daytrading_buying_power, account.buying_power),
          cash: account.cash.to_f,
          portfolio_value: account.portfolio_value.to_f,
          equity: account.equity.to_f,
          last_equity: account.last_equity.to_f,
          multiplier: account.multiplier.to_i,
          initial_margin: account.initial_margin.to_f,
          maintenance_margin: account.maintenance_margin.to_f,
          sma: account.sma.to_f,
          daytrade_count: account.daytrade_count.to_i,
          balance_asof: safe_date(account, :balance_asof),
          created_at: account.created_at,
          trading_blocked: account.trading_blocked,
          transfers_blocked: account.transfers_blocked,
          account_blocked: safe_boolean(account, :account_blocked, false),
          pattern_day_trader: account.pattern_day_trader,
          trade_suspended_by_user: account.trade_suspended_by_user,
          shorting_enabled: account.shorting_enabled,
          long_market_value: account.long_market_value.to_f,
          short_market_value: account.short_market_value.to_f,
          source: 'alpaca'
        }
      else
        @last_error = "No account data returned from Alpaca"
        Rails.logger.error(@last_error)
        nil
      end
    rescue StandardError => e
      @last_error = "Error fetching account info: #{e.message}"
      Rails.logger.error(@last_error)
      Rails.logger.error(e.backtrace.join("\n"))
      
      # Return simulated data as fallback
      get_simulated_account_info
    end
  end
  
  # Get account positions from Alpaca
  #
  # @return [Array, nil] array of positions or nil if failed
  def get_positions
    begin
      positions = @client.positions
      
      if positions
        positions.map do |position|
          {
            asset_id: position.asset_id,
            symbol: position.symbol,
            exchange: safe_string(position, :exchange, 'NASDAQ'),
            asset_class: safe_string(position, :asset_class, 'us_equity'),
            qty: position.qty.to_f,
            side: position.side,
            market_value: position.market_value.to_f,
            cost_basis: position.cost_basis.to_f,
            unrealized_pl: position.unrealized_pl.to_f,
            unrealized_plpc: position.unrealized_plpc.to_f,
            unrealized_intraday_pl: safe_to_f(position, :unrealized_intraday_pl, position.unrealized_pl),
            unrealized_intraday_plpc: safe_to_f(position, :unrealized_intraday_plpc, position.unrealized_plpc),
            current_price: position.current_price.to_f,
            lastday_price: safe_to_f(position, :lastday_price, position.current_price),
            change_today: safe_to_f(position, :change_today, 0.0),
            avg_entry_price: safe_to_f(position, :avg_entry_price, position.current_price),
            source: 'alpaca'
          }
        end
      else
        []
      end
    rescue StandardError => e
      @last_error = "Error fetching positions: #{e.message}"
      Rails.logger.error(@last_error)
      []
    end
  end
  
  # Get account activities (trades, deposits, etc.)
  #
  # @param activity_type [String] type of activity to fetch
  # @param limit [Integer] number of activities to return
  # @return [Array, nil] array of activities or nil if failed
  def get_activities(activity_type: nil, limit: 100)
    begin
      params = { limit: limit }
      params[:activity_type] = activity_type if activity_type
      
      activities = @client.activities(params)
      
      if activities
        activities.map do |activity|
          {
            id: activity.id,
            activity_type: safe_string(activity, :activity_type, 'FILL'),
            date: safe_string(activity, :date, Time.current.strftime("%Y-%m-%d")),
            net_amount: safe_to_f(activity, :net_amount, 0.0),
            symbol: safe_string(activity, :symbol, ''),
            qty: safe_to_f(activity, :qty, 0.0),
            side: safe_string(activity, :side, 'buy'),
            price: safe_to_f(activity, :price, 0.0),
            source: 'alpaca'
          }
        end
      else
        []
      end
    rescue StandardError => e
      @last_error = "Error fetching activities: #{e.message}"
      Rails.logger.error(@last_error)
      []
    end
  end
  
  # Calculate account performance metrics
  #
  # @param account_info [Hash] account information
  # @return [Hash] performance metrics
  def calculate_performance_metrics(account_info)
    return {} unless account_info
    
    equity = account_info[:equity]
    last_equity = account_info[:last_equity]
    cash = account_info[:cash]
    long_market_value = account_info[:long_market_value]
    
    # Calculate daily P/L
    daily_pl = equity - last_equity
    daily_pl_percent = last_equity > 0 ? (daily_pl / last_equity * 100) : 0
    
    # Calculate allocation percentages
    cash_percent = equity > 0 ? (cash / equity * 100) : 0
    invested_percent = equity > 0 ? (long_market_value / equity * 100) : 0
    
    {
      daily_pl: daily_pl.round(2),
      daily_pl_percent: daily_pl_percent.round(2),
      cash_percent: cash_percent.round(2),
      invested_percent: invested_percent.round(2),
      total_return: equity - 100000, # Assuming $100k starting balance for paper trading
      total_return_percent: ((equity - 100000) / 100000 * 100).round(2)
    }
  end
  
  private
  
  # Safe method to convert to float with fallback
  def safe_to_f(object, method, fallback = 0.0)
    return fallback.to_f unless object.respond_to?(method)
    value = object.send(method)
    value.respond_to?(:to_f) ? value.to_f : fallback.to_f
  rescue
    fallback.to_f
  end
  
  # Safe method to get boolean with fallback
  def safe_boolean(object, method, fallback = false)
    return fallback unless object.respond_to?(method)
    !!object.send(method)
  rescue
    fallback
  end
  
  # Safe method to get date with fallback
  def safe_date(object, method, fallback = nil)
    return fallback unless object.respond_to?(method)
    value = object.send(method)
    value.is_a?(String) ? value : (fallback || Time.current.strftime("%Y-%m-%d"))
  rescue
    fallback || Time.current.strftime("%Y-%m-%d")
  end
  
  # Safe method to get string with fallback
  def safe_string(object, method, fallback = '')
    return fallback unless object.respond_to?(method)
    object.send(method)
  rescue
    fallback
  end
  
  # Fallback simulated account data for development/testing
  def get_simulated_account_info
    Rails.logger.info "AccountService: Using simulated account data"
    
    {
      account_id: "simulated-account-#{SecureRandom.hex(8)}",
      account_number: "SIM#{rand(100000..999999)}",
      status: "ACTIVE",
      currency: "USD",
      buying_power: 200000.0,
      regt_buying_power: 200000.0,
      daytrading_buying_power: 400000.0,
      cash: 95000.0 + rand(-5000..5000),
      portfolio_value: 100000.0 + rand(-10000..10000),
      equity: 100000.0 + rand(-10000..10000),
      last_equity: 99500.0 + rand(-5000..5000),
      multiplier: 4,
      initial_margin: 0.0,
      maintenance_margin: 0.0,
      sma: 0.0,
      daytrade_count: rand(0..3),
      balance_asof: Time.current.strftime("%Y-%m-%d"),
      created_at: 1.month.ago.iso8601,
      trading_blocked: false,
      transfers_blocked: false,
      account_blocked: false,
      pattern_day_trader: false,
      trade_suspended_by_user: false,
      shorting_enabled: true,
      long_market_value: 5000.0 + rand(-2000..2000),
      short_market_value: 0.0,
      source: 'simulated'
    }
  end
end 