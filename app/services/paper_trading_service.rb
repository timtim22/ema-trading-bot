# frozen_string_literal: true

# Service to manage paper trading functionality and simulation
class PaperTradingService
  attr_reader :last_error
  
  def initialize
    @client = ALPACA_CLIENT
  end
  
  # Check if we're currently in paper trading mode
  #
  # @return [Boolean] true if paper trading is enabled
  def self.paper_trading_enabled?
    defined?(PAPER_TRADING) && PAPER_TRADING
  end
  
  # Get paper trading account information
  #
  # @return [Hash, nil] paper account info or nil if not in paper mode
  def get_paper_account_info
    return nil unless self.class.paper_trading_enabled?
    
    begin
      account = @client.account
      
      if account
        {
          account_id: account.id,
          status: account.status,
          currency: account.currency,
          buying_power: account.buying_power.to_f,
          cash: account.cash.to_f,
          portfolio_value: account.portfolio_value.to_f,
          equity: account.equity.to_f,
          day_trade_count: account.daytrade_count,
          pattern_day_trader: account.pattern_day_trader,
          trading_blocked: account.trading_blocked,
          account_blocked: account.account_blocked,
          mode: 'paper_trading',
          simulated: true,
          created_at: account.created_at
        }
      else
        @last_error = "No paper account data returned from Alpaca"
        Rails.logger.error(@last_error)
        nil
      end
    rescue StandardError => e
      @last_error = "Error fetching paper account info: #{e.message}"
      Rails.logger.error(@last_error)
      nil
    end
  end
  
  # Get all paper trading positions
  #
  # @return [Array] array of paper positions
  def get_paper_positions
    return [] unless self.class.paper_trading_enabled?
    
    begin
      positions = @client.positions
      
      positions.map do |position|
        {
          symbol: position.symbol,
          qty: position.qty.to_f,
          side: position.side,
          market_value: position.market_value.to_f,
          cost_basis: position.cost_basis.to_f,
          unrealized_pl: position.unrealized_pl.to_f,
          unrealized_plpc: position.unrealized_plpc.to_f,
          current_price: position.current_price.to_f,
          avg_entry_price: position.cost_basis.to_f / position.qty.to_f,
          mode: 'paper_trading',
          simulated: true
        }
      end
    rescue StandardError => e
      @last_error = "Error fetching paper positions: #{e.message}"
      Rails.logger.error(@last_error)
      []
    end
  end
  
  # Get paper trading order history
  #
  # @param status [String] filter by order status (optional)
  # @param limit [Integer] number of orders to return
  # @return [Array] array of paper orders
  def get_paper_orders(status: nil, limit: 100)
    return [] unless self.class.paper_trading_enabled?
    
    begin
      params = { limit: limit }
      params[:status] = status if status
      
      orders = @client.orders(params)
      
      orders.map do |order|
        {
          id: order.id,
          client_order_id: order.client_order_id,
          symbol: order.symbol,
          side: order.side,
          order_type: order.order_type,
          qty: order.qty.to_f,
          filled_qty: order.filled_qty.to_f,
          status: order.status,
          time_in_force: order.time_in_force,
          limit_price: order.limit_price&.to_f,
          stop_price: order.stop_price&.to_f,
          filled_avg_price: order.filled_avg_price&.to_f,
          submitted_at: order.submitted_at,
          filled_at: order.filled_at,
          mode: 'paper_trading',
          simulated: true
        }
      end
    rescue StandardError => e
      @last_error = "Error fetching paper orders: #{e.message}"
      Rails.logger.error(@last_error)
      []
    end
  end
  
  # Calculate paper trading performance metrics
  #
  # @return [Hash] performance metrics for paper trading
  def calculate_paper_performance
    return {} unless self.class.paper_trading_enabled?
    
    account_info = get_paper_account_info
    return {} unless account_info
    
    positions = get_paper_positions
    orders = get_paper_orders(status: 'filled')
    
    total_unrealized_pl = positions.sum { |p| p[:unrealized_pl] }
    total_trades = orders.count
    winning_trades = orders.count { |o| (o[:filled_avg_price] || 0) > 0 }
    
    initial_balance = defined?(PAPER_TRADING_INITIAL_BALANCE) ? PAPER_TRADING_INITIAL_BALANCE : 100000.0
    current_equity = account_info[:equity]
    total_return = current_equity - initial_balance
    total_return_percent = initial_balance > 0 ? (total_return / initial_balance * 100) : 0
    
    {
      mode: 'paper_trading',
      simulated: true,
      initial_balance: initial_balance,
      current_equity: current_equity,
      total_return: total_return,
      total_return_percent: total_return_percent.round(2),
      unrealized_pl: total_unrealized_pl,
      total_trades: total_trades,
      winning_trades: winning_trades,
      win_rate: total_trades > 0 ? (winning_trades.to_f / total_trades * 100).round(2) : 0,
      active_positions: positions.count,
      buying_power: account_info[:buying_power],
      day_trade_count: account_info[:day_trade_count],
      pattern_day_trader: account_info[:pattern_day_trader]
    }
  end
  
  # Reset paper trading account (if supported by Alpaca)
  # Note: This functionality may require manual reset through Alpaca dashboard
  #
  # @param new_balance [Float] new starting balance
  # @return [Boolean] success status
  def reset_paper_account(new_balance = 100000.0)
    return false unless self.class.paper_trading_enabled?
    
    Rails.logger.warn "Paper account reset requested with balance: $#{new_balance}"
    Rails.logger.warn "Note: Paper account reset must be done through Alpaca dashboard"
    Rails.logger.warn "Visit: https://app.alpaca.markets/paper/dashboard/overview"
    
    # Store the intended balance for reference
    @intended_balance = new_balance
    
    # Return false as this requires manual action
    false
  end
  
  # Get trading mode information
  #
  # @return [Hash] current trading mode details
  def self.get_trading_mode_info
    {
      mode: paper_trading_enabled? ? 'paper_trading' : 'live_trading',
      simulated: paper_trading_enabled?,
      endpoint: defined?(ALPACA_ENDPOINT) ? ALPACA_ENDPOINT : 'unknown',
      description: paper_trading_enabled? ? 'Simulated trading with fake money' : 'Real trading with actual money',
      initial_balance: paper_trading_enabled? && defined?(PAPER_TRADING_INITIAL_BALANCE) ? PAPER_TRADING_INITIAL_BALANCE : nil,
      warning: paper_trading_enabled? ? nil : '⚠️  LIVE TRADING MODE - Real money at risk!'
    }
  end
  
  # Validate paper trading environment
  #
  # @return [Hash] validation results
  def self.validate_paper_environment
    results = {
      paper_mode_enabled: paper_trading_enabled?,
      endpoint_correct: false,
      api_keys_present: false,
      client_configured: false,
      warnings: [],
      errors: []
    }
    
    # Check endpoint
    if defined?(ALPACA_ENDPOINT)
      results[:endpoint_correct] = ALPACA_ENDPOINT.include?('paper-api') if paper_trading_enabled?
      results[:endpoint_correct] = !ALPACA_ENDPOINT.include?('paper-api') unless paper_trading_enabled?
    end
    
    # Check API keys
    results[:api_keys_present] = ENV['ALPACA_API_KEY_ID'].present? && ENV['ALPACA_API_SECRET_KEY'].present?
    
    # Check client
    results[:client_configured] = defined?(ALPACA_CLIENT) && ALPACA_CLIENT.present?
    
    # Add warnings and errors
    if paper_trading_enabled?
      results[:warnings] << "Using paper trading - all trades are simulated"
      results[:warnings] << "Reset paper account through Alpaca dashboard if needed"
    else
      results[:errors] << "⚠️  LIVE TRADING MODE - Real money will be used!"
    end
    
    unless results[:api_keys_present]
      results[:errors] << "Missing Alpaca API keys in environment variables"
    end
    
    unless results[:endpoint_correct]
      mode = paper_trading_enabled? ? 'paper' : 'live'
      results[:errors] << "Endpoint mismatch for #{mode} trading mode"
    end
    
    results
  end
end 