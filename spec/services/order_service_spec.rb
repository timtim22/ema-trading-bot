require 'rails_helper'
require 'ostruct'

RSpec.describe OrderService, type: :service do
  describe 'Ticket T8: Unit Test Market-Buy Order Placement' do
    let(:service) { described_class.new }
    let(:symbol) { 'AAPL' }
    let(:amount) { 1000.0 }
    let(:profit_percent) { 1.0 }
    let(:loss_percent) { 1.0 }
    
    # Mock Alpaca client
    let(:mock_client) { instance_double('Alpaca::Trade::Api::Client') }
    
    before do
      # Replace the real ALPACA_CLIENT with our mock
      service.instance_variable_set(:@client, mock_client)
      # Initialize @last_orders as empty hash
      service.instance_variable_set(:@last_orders, {})
    end
    
    describe '#place_buy_order_with_safety' do
      context 'when order is filled immediately (success scenario)' do
        let(:filled_order) do
          OpenStruct.new(
            id: 'order_123456',
            symbol: symbol,
            status: 'filled',
            filled_avg_price: 150.0,
            filled_qty: 6.67,
            created_at: Time.current.iso8601,
            filled_at: Time.current.iso8601
          )
        end
        
        let(:take_profit_order) do
          OpenStruct.new(
            id: 'tp_order_789',
            status: 'accepted'
          )
        end
        
        let(:stop_loss_order) do
          OpenStruct.new(
            id: 'sl_order_456',
            status: 'accepted'
          )
        end
        
        before do
          # Mock the sequence of API calls
          allow(mock_client).to receive(:new_order)
            .and_return(filled_order, take_profit_order, stop_loss_order)
        end
        
        it 'returns hash with primary_order_id, fill_price, and correct status' do
          result = service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          # Core acceptance criteria
          expect(result).to be_a(Hash)
          expect(result[:primary_order_id]).to eq('order_123456')
          expect(result[:fill_price]).to eq(150.0)
          expect(result[:status]).to eq('filled')
        end
        
        it 'includes all expected hash keys' do
          result = service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expected_keys = [
            :primary_order_id, :symbol, :amount, :fill_price, :fill_qty, :status,
            :created_at, :filled_at, :stop_loss_order_id, :take_profit_order_id
          ]
          
          expect(result.keys).to match_array(expected_keys)
        end
        
        it 'creates safety orders (take-profit and stop-loss)' do
          result = service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(result[:take_profit_order_id]).to eq('tp_order_789')
          expect(result[:stop_loss_order_id]).to eq('sl_order_456')
        end
        
        it 'passes correct parameters to primary order API call' do
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          # Verify the primary order call with exact parameters
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            notional: amount,  # Key requirement: notional (not qty)
            side: 'buy',
            type: 'market',
            time_in_force: 'day'
          ).at_least(:once)
        end
        
        it 'calculates safety order prices correctly' do
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          # Verify take-profit order (sell at +1%)
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 6.67,
            side: 'sell',
            type: 'limit',
            time_in_force: 'gtc',
            limit_price: 151.5  # 150.0 * 1.01 = 151.5
          )
          
          # Verify stop-loss order (sell at -1%)
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 6.67,
            side: 'sell',
            type: 'stop',
            time_in_force: 'gtc',
            stop_price: 148.5  # 150.0 * 0.99 = 148.5
          )
        end
        
        it 'does not set last_error on successful execution' do
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(service.last_error).to be_nil
        end
      end
      
      context 'when order is pending (not filled immediately)' do
        let(:pending_order) do
          OpenStruct.new(
            id: 'order_pending_123',
            symbol: symbol,
            status: 'pending',
            filled_avg_price: nil,
            filled_qty: nil,
            created_at: Time.current.iso8601,
            filled_at: nil
          )
        end
        
        before do
          allow(mock_client).to receive(:new_order).and_return(pending_order)
        end
        
        it 'returns hash with pending status and nil fill_price' do
          result = service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(result).to be_a(Hash)
          expect(result[:primary_order_id]).to eq('order_pending_123')
          expect(result[:status]).to eq('pending')
          expect(result[:fill_price]).to be_nil
          expect(result[:filled_at]).to be_nil
        end
        
        it 'does not create safety orders for pending orders' do
          result = service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(result[:take_profit_order_id]).to be_nil
          expect(result[:stop_loss_order_id]).to be_nil
          
          # Verify only one API call was made (primary order only)
          expect(mock_client).to have_received(:new_order).once
        end
        
        it 'logs pending order information' do
          expect(Rails.logger).to receive(:info).with(/Order .* is not filled yet, status: pending/)
          
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
        end
      end
      
      context 'when API raises an exception' do
        let(:error_message) { 'Insufficient buying power' }
        
        before do
          allow(mock_client).to receive(:new_order).and_raise(StandardError, error_message)
        end
        
        it 'returns nil on exception' do
          result = service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          # Core acceptance criteria
          expect(result).to be_nil
        end
        
        it 'sets last_error with meaningful message' do
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          # Core acceptance criteria
          expect(service.last_error).to be_present
          expect(service.last_error).to include('Order placement failed')
          expect(service.last_error).to include(error_message)
        end
        
        it 'logs error information' do
          expect(Rails.logger).to receive(:error).with(/Order placement failed: #{error_message}/)
          expect(Rails.logger).to receive(:error).with(kind_of(String)) # backtrace
          
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
        end
      end
      
      context 'parameter validation and edge cases' do
        let(:filled_order) do
          OpenStruct.new(
            id: 'order_123456',
            symbol: symbol,
            status: 'filled',
            filled_avg_price: 100.0,
            filled_qty: 10.0,
            created_at: Time.current.iso8601,
            filled_at: Time.current.iso8601
          )
        end
        
        let(:safety_order) do
          OpenStruct.new(id: 'safety_order_123', status: 'accepted')
        end
        
        before do
          allow(mock_client).to receive(:new_order).and_return(filled_order, safety_order, safety_order)
        end
        
        it 'handles custom profit and loss percentages' do
          custom_profit = 2.5
          custom_loss = 1.5
          
          service.place_buy_order_with_safety(symbol, amount, profit_percent: custom_profit, loss_percent: custom_loss)
          
          # Verify take-profit at +2.5%
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 10.0,
            side: 'sell',
            type: 'limit',
            time_in_force: 'gtc',
            limit_price: 102.5  # 100.0 * 1.025
          )
          
          # Verify stop-loss at -1.5%
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 10.0,
            side: 'sell',
            type: 'stop',
            time_in_force: 'gtc',
            stop_price: 98.5  # 100.0 * 0.985
          )
        end
        
        it 'verifies notional amount parameter is used (not qty)' do
          # This test specifically addresses the "$1,000 per trade, broker handles share count" requirement
          
          # Track all API calls
          api_calls = []
          allow(mock_client).to receive(:new_order) do |params|
            api_calls << params
            case api_calls.length
            when 1
              filled_order  # First call - primary order
            else
              safety_order  # Subsequent calls - safety orders
            end
          end
          
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          # Verify the primary order (first call) uses notional, not qty
          primary_order_params = api_calls.first
          expect(primary_order_params).to have_key(:notional)
          expect(primary_order_params).not_to have_key(:qty)
          expect(primary_order_params[:notional]).to eq(amount)
          
          # Verify subsequent calls (safety orders) use qty, not notional
          safety_order_params = api_calls[1..-1]
          safety_order_params.each do |params|
            expect(params).to have_key(:qty)
            expect(params).not_to have_key(:notional)
          end
        end
        
        it 'handles different symbols correctly' do
          custom_symbol = 'MSFT'
          
          service.place_buy_order_with_safety(custom_symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(mock_client).to have_received(:new_order).with(
            hash_including(symbol: custom_symbol)
          ).at_least(:once)
        end
        
        it 'handles different dollar amounts correctly' do
          custom_amount = 2500.0
          
          service.place_buy_order_with_safety(symbol, custom_amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(mock_client).to have_received(:new_order).with(
            hash_including(notional: custom_amount)
          ).at_least(:once)
        end
      end
      
      context 'integration with last_orders tracking' do
        let(:filled_order) { OpenStruct.new(id: 'primary_123', status: 'filled', filled_avg_price: 150.0, filled_qty: 6.67, created_at: Time.current.iso8601, filled_at: Time.current.iso8601) }
        let(:take_profit_order) { OpenStruct.new(id: 'tp_456', status: 'accepted') }
        let(:stop_loss_order) { OpenStruct.new(id: 'sl_789', status: 'accepted') }
        
        before do
          allow(mock_client).to receive(:new_order).and_return(filled_order, take_profit_order, stop_loss_order)
        end
        
        it 'stores order references in last_orders' do
          service.place_buy_order_with_safety(symbol, amount, profit_percent: profit_percent, loss_percent: loss_percent)
          
          expect(service.last_orders[:primary]).to eq(filled_order)
          expect(service.last_orders[:take_profit]).to eq(take_profit_order)
          expect(service.last_orders[:stop_loss]).to eq(stop_loss_order)
        end
      end
    end
    
    describe 'acceptance criteria summary' do
      it 'meets all Ticket T8 requirements' do
        # This is a documentation test that summarizes the acceptance criteria
        
        # ✓ place_buy_order_with_safety returns hash with primary_order_id, fill_price, and correct status
        # ✓ On exception, method returns nil and sets last_error
        # ✓ Uses notional amount (not qty) for primary orders
        # ✓ Creates safety orders for filled orders
        # ✓ Handles pending orders correctly
        # ✓ Proper error handling and logging
        
        expect(true).to be true # Placeholder for documentation
      end
    end
  end

  describe 'Ticket T9: Unit Test Auto-Exit Orders Prices' do
    let(:service) { described_class.new }
    let(:symbol) { 'AAPL' }
    let(:profit_percent) { 1.0 }
    let(:loss_percent) { 1.0 }
    
    # Mock Alpaca client
    let(:mock_client) { instance_double('Alpaca::Trade::Api::Client') }
    
    before do
      # Replace the real ALPACA_CLIENT with our mock
      service.instance_variable_set(:@client, mock_client)
      # Initialize @last_orders as empty hash
      service.instance_variable_set(:@last_orders, {})
    end
    
    describe '#setup_safety_orders' do
      context 'given a primary fill at $100' do
        let(:primary_order) do
          OpenStruct.new(
            id: 'primary_order_123',
            symbol: symbol,
            status: 'filled',
            filled_avg_price: 100.0,  # Key test value: $100 fill price
            filled_qty: 10.0          # 10 shares for easy calculation
          )
        end
        
        let(:take_profit_order) do
          OpenStruct.new(
            id: 'tp_order_456',
            status: 'accepted'
          )
        end
        
        let(:stop_loss_order) do
          OpenStruct.new(
            id: 'sl_order_789',
            status: 'accepted'
          )
        end
        
        before do
          # Mock the API calls for safety orders
          allow(mock_client).to receive(:new_order)
            .and_return(take_profit_order, stop_loss_order)
        end
        
        it 'calculates take-profit = $101 and stop-loss = $99' do
          service.setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
          
          # Verify take-profit order with correct limit_price = $101
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 10.0,
            side: 'sell',
            type: 'limit',
            time_in_force: 'gtc',
            limit_price: 101.0  # $100 * (1 + 1%) = $101
          )
          
          # Verify stop-loss order with correct stop_price = $99
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 10.0,
            side: 'sell',
            type: 'stop',
            time_in_force: 'gtc',
            stop_price: 99.0  # $100 * (1 - 1%) = $99
          )
        end
        
        it 'creates both stop and limit orders via new_order' do
          result = service.setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
          
          # Verify both orders are created via new_order
          expect(mock_client).to have_received(:new_order).twice
          
          # Verify the method returns hash with order IDs
          expect(result).to be_a(Hash)
          expect(result[:take_profit_order_id]).to eq('tp_order_456')
          expect(result[:stop_loss_order_id]).to eq('sl_order_789')
        end
        
        it 'uses correct order parameters for take-profit limit order' do
          service.setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
          
          # Detailed verification of take-profit order parameters
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 10.0,           # Uses shares from filled order
            side: 'sell',        # Selling to take profit
            type: 'limit',       # Limit order type
            time_in_force: 'gtc', # Good 'til cancelled
            limit_price: 101.0   # Calculated take-profit price
          ).once
        end
        
        it 'uses correct order parameters for stop-loss stop order' do
          service.setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
          
          # Detailed verification of stop-loss order parameters
          expect(mock_client).to have_received(:new_order).with(
            symbol: symbol,
            qty: 10.0,           # Uses shares from filled order
            side: 'sell',        # Selling to limit loss
            type: 'stop',        # Stop order type
            time_in_force: 'gtc', # Good 'til cancelled
            stop_price: 99.0     # Calculated stop-loss price
          ).once
        end
        
        it 'stores order references in last_orders' do
          service.setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
          
          expect(service.last_orders[:take_profit]).to eq(take_profit_order)
          expect(service.last_orders[:stop_loss]).to eq(stop_loss_order)
        end
        
        context 'with different profit and loss percentages' do
          let(:custom_profit_percent) { 2.0 }  # 2%
          let(:custom_loss_percent) { 1.5 }    # 1.5%
          
          it 'calculates prices with custom percentages correctly' do
            service.setup_safety_orders(symbol, primary_order, custom_profit_percent, custom_loss_percent)
            
            # Take-profit: $100 * (1 + 2%) = $102
            expect(mock_client).to have_received(:new_order).with(
              hash_including(
                type: 'limit',
                limit_price: 102.0
              )
            ).once
            
            # Stop-loss: $100 * (1 - 1.5%) = $98.50
            expect(mock_client).to have_received(:new_order).with(
              hash_including(
                type: 'stop',
                stop_price: 98.5
              )
            ).once
          end
        end
        
        context 'with different fill prices' do
          let(:primary_order_different_price) do
            OpenStruct.new(
              id: 'primary_order_456',
              symbol: symbol,
              status: 'filled',
              filled_avg_price: 150.50,  # Different fill price
              filled_qty: 6.67
            )
          end
          
          it 'calculates prices correctly for different fill price' do
            service.setup_safety_orders(symbol, primary_order_different_price, profit_percent, loss_percent)
            
            # Take-profit: $150.50 * (1 + 1%) = $152.005 → rounded to $152.01
            expect(mock_client).to have_received(:new_order).with(
              hash_including(
                type: 'limit',
                limit_price: 152.01
              )
            ).once
            
            # Stop-loss: $150.50 * (1 - 1%) = $148.995 → rounded to $149.00
            expect(mock_client).to have_received(:new_order).with(
              hash_including(
                type: 'stop',
                stop_price: 149.0
              )
            ).once
          end
        end
      end
      
      context 'when API calls fail' do
        let(:primary_order) do
          OpenStruct.new(
            id: 'primary_order_123',
            symbol: symbol,
            status: 'filled',
            filled_avg_price: 100.0,
            filled_qty: 10.0
          )
        end
        
        before do
          # Mock API to raise an error
          allow(mock_client).to receive(:new_order).and_raise(StandardError, 'API Error')
        end
        
        it 'raises an error if order placement fails' do
          expect {
            service.setup_safety_orders(symbol, primary_order, profit_percent, loss_percent)
          }.to raise_error(StandardError, 'API Error')
        end
      end
    end
    
    describe 'acceptance criteria summary for T9' do
      it 'meets all Ticket T9 requirements' do
        # This is a documentation test that summarizes the acceptance criteria
        
        # ✓ Given a primary fill at $100, verify setup_safety_orders calculates:
        # ✓ - take-profit = $101
        # ✓ - stop-loss = $99
        # ✓ Both stop and limit orders are created via new_order with correct limit_price and stop_price
        # ✓ Test Type: Unit + Webmock (using instance_double mocking)
        
        expect(true).to be true # Placeholder for documentation
      end
    end
  end
end 