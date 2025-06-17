# frozen_string_literal: true

# Service to handle order placement and management via Alpaca API
class OrderService
  attr_reader :last_error, :last_orders
  
  def initialize
    @client = ALPACA_CLIENT
    @last_orders = {}
  end
  
  # Place a market buy order and setup stop-loss and take-profit orders
  #
  # @param symbol [String] the stock symbol (e.g., "AAPL")
  # @param amount [Float] dollar amount to buy (notional)
  # @param profit_percent [Float] percentage for take-profit (default: 1.0)
  # @param loss_percent [Float] percentage for stop-loss (default: 1.0)
  # @return [Hash] order information or nil if failed
  def place_buy_order_with_safety(symbol, amount, profit_percent: 1.0, loss_percent: 1.0)
    begin
      # Place the primary market buy order
      primary_order = @client.new_order(
        symbol: symbol,
        notional: amount,
        side: 'buy',
        type: 'market',
        time_in_force: 'day'
      )
      
      # Store the primary order details
      @last_orders[:primary] = primary_order
      
      # If the order is filled immediately, we can set up stop-loss and take-profit
      if primary_order.status == 'filled'
        setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
      else
        # Set up a listener to wait for the order to be filled
        # In a production environment, this would be handled by a background job or webhook
        Rails.logger.info("Order #{primary_order.id} is not filled yet, status: #{primary_order.status}")
      end
      
      result = {
        primary_order_id: primary_order.id,
        symbol: symbol,
        amount: amount,
        fill_price: primary_order.filled_avg_price&.to_f,
        fill_qty: primary_order.filled_qty&.to_f,
        status: primary_order.status,
        created_at: primary_order.created_at,
        filled_at: primary_order.filled_at,
        stop_loss_order_id: @last_orders.dig(:stop_loss, :id),
        take_profit_order_id: @last_orders.dig(:take_profit, :id)
      }
      
      # TODO: Persist these order IDs to the Position record
      # position.update(
      #   primary_order_id: primary_order.id,
      #   stop_loss_order_id: @last_orders.dig(:stop_loss, :id),
      #   take_profit_order_id: @last_orders.dig(:take_profit, :id)
      # )
      
      return result
    rescue StandardError => e
      @last_error = "Order placement failed: #{e.message}"
      Rails.logger.error(@last_error)
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end
  end
  
  # Setup stop-loss and take-profit orders for an existing position
  #
  # @param symbol [String] the stock symbol
  # @param primary_order [Alpaca::Trade::Order] the filled primary order
  # @param profit_percent [Float] percentage for take-profit
  # @param loss_percent [Float] percentage for stop-loss
  # @return [Hash] hash with the order IDs
  def setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
    # Get fill price and calculate shares
    fill_price = primary_order.filled_avg_price.to_f
    shares = primary_order.filled_qty.to_f
    
    # Calculate take-profit and stop-loss prices
    take_profit_price = fill_price * (1 + profit_percent / 100.0)
    stop_loss_price = fill_price * (1 - loss_percent / 100.0)
    
    # Place a limit order for take-profit
    take_profit_order = @client.new_order(
      symbol: symbol,
      qty: shares,
      side: 'sell',
      type: 'limit',
      time_in_force: 'gtc',  # Good 'til cancelled
      limit_price: take_profit_price.round(2)
      # Removed order_class: 'oto' as we're creating separate orders
    )
    @last_orders[:take_profit] = take_profit_order
    
    # Place a stop-market order for stop-loss
    stop_loss_order = @client.new_order(
      symbol: symbol,
      qty: shares,
      side: 'sell',
      type: 'stop',
      time_in_force: 'gtc',  # Good 'til cancelled
      stop_price: stop_loss_price.round(2)
      # Removed order_class: 'oto' as we're creating separate orders
    )
    @last_orders[:stop_loss] = stop_loss_order
    
    {
      take_profit_order_id: take_profit_order.id,
      stop_loss_order_id: stop_loss_order.id
    }
  end
  
  # Get the status of an order
  #
  # @param order_id [String] the Alpaca order ID
  # @return [Alpaca::Trade::Order, nil] the order object or nil if error
  def get_order_status(order_id)
    begin
      @client.order(order_id)
    rescue StandardError => e
      @last_error = "Error getting order status: #{e.message}"
      Rails.logger.error(@last_error)
      nil
    end
  end
  
  # Cancel all open orders for a symbol
  #
  # @param symbol [String] the stock symbol
  # @return [Boolean] whether the cancellation was successful
  def cancel_orders_for_symbol(symbol)
    begin
      @client.cancel_orders
      true
    rescue StandardError => e
      @last_error = "Error cancelling orders: #{e.message}"
      Rails.logger.error(@last_error)
      false
    end
  end
end 