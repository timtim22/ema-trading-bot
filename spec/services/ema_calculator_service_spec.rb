require 'rails_helper'

RSpec.describe EmaCalculatorService, type: :service do
  describe '.calculate_ema' do
    context 'with known price series from Ticket T1' do
      it 'returns correct hand-calculated EMA' do
        # Test data from Ticket T1: [1,2,3,4,5,6,7] with period=5
        prices = [1, 2, 3, 4, 5, 6, 7]
        period = 5
        
        # Hand calculation:
        # α = 2/(5+1) = 2/6 = 0.3333...
        # SMA for first 5 values = (1+2+3+4+5)/5 = 3.0
        # EMA₅ = 3.0 (initial SMA seed)
        # EMA₆ = (6 - 3.0) × 0.3333 + 3.0 = 4.0
        # EMA₇ = (7 - 4.0) × 0.3333 + 4.0 = 5.0
        expected_ema = 5.0
        
        result = described_class.calculate_ema(prices, period)
        
        expect(result).not_to be_nil
        expect(result).to be_within(0.001).of(expected_ema)
      end
    end
    
    context 'with minimum data (SMA seed)' do
      it 'uses SMA as initial value when period equals price count' do
        # Test with exactly the minimum number of prices (period length)
        prices = [1, 2, 3, 4, 5]
        period = 5
        
        # When we have exactly period number of prices, result should be SMA
        expected_sma = (1 + 2 + 3 + 4 + 5) / 5.0  # = 3.0
        
        result = described_class.calculate_ema(prices, period)
        
        expect(result).not_to be_nil
        expect(result).to be_within(0.001).of(expected_sma)
      end
    end
    
    context 'with multi-step recursion' do
      it 'calculates EMA correctly through multiple iterations' do
        # Test with a longer series to verify recursive calculation
        prices = [10, 20, 30, 40, 50, 60, 70, 80]
        period = 3
        
        # Hand calculation for period=3:
        # α = 2/(3+1) = 0.5
        # SMA for first 3 = (10+20+30)/3 = 20.0
        # EMA₃ = 20.0
        # EMA₄ = (40 - 20.0) × 0.5 + 20.0 = 30.0
        # EMA₅ = (50 - 30.0) × 0.5 + 30.0 = 40.0
        # EMA₆ = (60 - 40.0) × 0.5 + 40.0 = 50.0
        # EMA₇ = (70 - 50.0) × 0.5 + 50.0 = 60.0
        # EMA₈ = (80 - 60.0) × 0.5 + 60.0 = 70.0
        expected_ema = 70.0
        
        result = described_class.calculate_ema(prices, period)
        
        expect(result).not_to be_nil
        expect(result).to be_within(0.001).of(expected_ema)
      end
    end
    
    context 'with custom smoothing factor' do
      it 'uses correct alpha calculation with custom smoothing' do
        # Verify the alpha calculation: α = smoothing/(period + 1)
        prices = [1, 2, 3, 4, 5, 6]
        period = 5
        
        # With custom smoothing factor
        custom_smoothing = 3
        expected_alpha = custom_smoothing / (period + 1.0)  # 3/6 = 0.5
        
        # Hand calculation with α = 0.5:
        # SMA = (1+2+3+4+5)/5 = 3.0
        # EMA₆ = (6 - 3.0) × 0.5 + 3.0 = 4.5
        expected_ema = 4.5
        
        result = described_class.calculate_ema(prices, period, custom_smoothing)
        
        expect(result).not_to be_nil
        expect(result).to be_within(0.001).of(expected_ema)
      end
    end
    
    context 'with insufficient data' do
      it 'returns nil when prices array is shorter than period' do
        prices = [1, 2, 3]
        period = 5
        
        result = described_class.calculate_ema(prices, period)
        
        expect(result).to be_nil
      end
      
      it 'returns nil for empty array' do
        prices = []
        period = 5
        
        result = described_class.calculate_ema(prices, period)
        
        expect(result).to be_nil
      end
    end
    
    context 'step-by-step verification' do
      it 'matches manual calculation exactly' do
        # More detailed verification to ensure each step is correct
        prices = [1, 2, 3, 4, 5, 6, 7]
        period = 5
        
        # Step-by-step manual calculation for verification
        alpha = 2.0 / (period + 1.0)  # 2/6 = 0.3333...
        
        # Step 1: SMA of first 5 prices
        sma = prices.first(period).sum / period.to_f  # (1+2+3+4+5)/5 = 3.0
        
        # Step 2: Apply EMA formula for remaining prices
        ema = sma
        remaining_prices = prices[period..-1]  # [6, 7]
        
        remaining_prices.each do |price|
          ema = (price - ema) * alpha + ema
        end
        
        # This should match our service calculation
        result = described_class.calculate_ema(prices, period)
        
        expect(result).not_to be_nil
        expect(result).to be_within(0.0001).of(ema)
      end
    end
  end
  
  # NEW: Ticket T2 Tests
  describe '.calculate_ema_series' do
    context 'with 30 sequential prices from Ticket T2' do
      let(:prices) { (1..30).to_a }  # [1, 2, 3, ..., 30]
      let(:periods) { [5, 8, 22] }
      
      it 'produces correct length arrays for each period' do
        result = described_class.calculate_ema_series(prices, periods)
        
        expect(result).not_to be_empty
        expect(result[:values]).to be_a(Hash)
        
        # According to Ticket T2 acceptance criteria:
        # Input 30 sequential prices; expect values[5].length == 26 (30−5+1)
        expect(result[:values][5]).to be_an(Array)
        expect(result[:values][5].length).to eq(26), "Expected EMA-5 array length to be 26 (30-5+1), got #{result[:values][5].length}"
        
        # Likewise for period 8: should be 23 (30-8+1)
        expect(result[:values][8]).to be_an(Array)
        expect(result[:values][8].length).to eq(23), "Expected EMA-8 array length to be 23 (30-8+1), got #{result[:values][8].length}"
        
        # And for period 22: should be 9 (30-22+1)
        expect(result[:values][22]).to be_an(Array)
        expect(result[:values][22].length).to eq(9), "Expected EMA-22 array length to be 9 (30-22+1), got #{result[:values][22].length}"
      end
      
      it 'latest entries match single-value calculate_ema calls' do
        result = described_class.calculate_ema_series(prices, periods)
        
        # Test that latest entries in result hash match single calculate_ema calls
        periods.each do |period|
          expected_single_ema = described_class.calculate_ema(prices, period)
          actual_latest_from_series = result[period]
          actual_latest_from_array = result[:values][period].last
          
          expect(actual_latest_from_series).not_to be_nil
          expect(actual_latest_from_array).not_to be_nil
          expect(expected_single_ema).not_to be_nil
          
          expect(actual_latest_from_series).to be_within(0.0001).of(expected_single_ema),
            "Latest EMA-#{period} from series (#{actual_latest_from_series}) should match single calculate_ema (#{expected_single_ema})"
          
          expect(actual_latest_from_array).to be_within(0.0001).of(expected_single_ema),
            "Latest EMA-#{period} from array (#{actual_latest_from_array}) should match single calculate_ema (#{expected_single_ema})"
          
          expect(actual_latest_from_series).to eq(actual_latest_from_array),
            "Latest value in hash should match last value in array for period #{period}"
        end
      end
    end
    
    context 'with insufficient data' do
      it 'returns empty hash when prices array is shorter than max period' do
        prices = (1..20).to_a  # Only 20 prices
        periods = [5, 8, 22]   # Max period is 22, but we only have 20 prices
        
        result = described_class.calculate_ema_series(prices, periods)
        
        expect(result).to eq({})
      end
      
      it 'returns empty hash for empty prices array' do
        prices = []
        periods = [5, 8, 22]
        
        result = described_class.calculate_ema_series(prices, periods)
        
        expect(result).to eq({})
      end
    end
    
    context 'with minimum required data' do
      it 'works when prices length exactly equals max period' do
        prices = (1..22).to_a  # Exactly 22 prices
        periods = [5, 8, 22]
        
        result = described_class.calculate_ema_series(prices, periods)
        
        expect(result).not_to be_empty
        expect(result[:values][22].length).to eq(1)  # Should have exactly 1 EMA-22 value
        expect(result[22]).not_to be_nil
      end
    end
    
    context 'with different period combinations' do
      it 'handles single period correctly' do
        prices = (1..10).to_a
        periods = [5]
        
        result = described_class.calculate_ema_series(prices, periods)
        
        expect(result[:values][5].length).to eq(6)  # 10-5+1 = 6
        expect(result[5]).to eq(result[:values][5].last)
      end
      
      it 'handles custom period combinations' do
        prices = (1..15).to_a
        periods = [3, 7, 10]
        
        result = described_class.calculate_ema_series(prices, periods)
        
        expect(result[:values][3].length).to eq(13)  # 15-3+1 = 13
        expect(result[:values][7].length).to eq(9)   # 15-7+1 = 9
        expect(result[:values][10].length).to eq(6)  # 15-10+1 = 6
      end
    end
    
    context 'result structure validation' do
      let(:prices) { (1..25).to_a }
      let(:periods) { [5, 8, 22] }
      
      it 'returns properly structured hash' do
        result = described_class.calculate_ema_series(prices, periods)
        
        # Check top-level structure
        expect(result).to have_key(:values)
        expect(result).to have_key(5)
        expect(result).to have_key(8)
        expect(result).to have_key(22)
        
        # Check values structure
        expect(result[:values]).to have_key(5)
        expect(result[:values]).to have_key(8)
        expect(result[:values]).to have_key(22)
        
        # Check all arrays contain numeric values
        periods.each do |period|
          expect(result[:values][period]).to all(be_a(Numeric))
          expect(result[period]).to be_a(Numeric)
        end
      end
      
      it 'all EMA values are reasonable' do
        result = described_class.calculate_ema_series(prices, periods)
        
        # EMA values should be within reasonable range of input prices
        min_price = prices.min
        max_price = prices.max
        
        periods.each do |period|
          result[:values][period].each do |ema_value|
            expect(ema_value).to be >= (min_price * 0.5)  # Allow some smoothing below min
            expect(ema_value).to be <= (max_price * 1.5)  # Allow some smoothing above max
          end
        end
      end
    end
  end
  
  describe 'performance characteristics' do
    it 'handles large datasets efficiently' do
      # Test with a large dataset to ensure performance
      large_prices = Array.new(1000) { |i| 100 + (i % 10) }
      period = 50
      
      start_time = Time.current
      result = described_class.calculate_ema(large_prices, period)
      duration = Time.current - start_time
      
      expect(result).not_to be_nil
      expect(duration).to be < 0.1  # Should complete in under 100ms
    end
    
    it 'handles large series efficiently' do
      # Test calculate_ema_series with large dataset
      large_prices = Array.new(500) { |i| 100 + (i % 20) }
      periods = [5, 8, 22, 50]
      
      start_time = Time.current
      result = described_class.calculate_ema_series(large_prices, periods)
      duration = Time.current - start_time
      
      expect(result).not_to be_empty
      expect(duration).to be < 0.5  # Should complete in under 500ms
    end
  end
  
  describe 'edge cases' do
    it 'handles period of 1 correctly' do
      prices = [5, 10, 15]
      period = 1
      
      result = described_class.calculate_ema(prices, period)
      
      # With period=1, EMA should equal the last price
      expect(result).to eq(15)
    end
    
    it 'handles identical prices' do
      prices = [100, 100, 100, 100, 100]
      period = 3
      
      result = described_class.calculate_ema(prices, period)
      
      # All prices the same, EMA should be that price
      expect(result).to eq(100)
    end
    
    it 'handles negative prices' do
      prices = [-1, -2, -3, -4, -5]
      period = 3
      
      result = described_class.calculate_ema(prices, period)
      
      expect(result).not_to be_nil
      expect(result).to be < 0
    end
  end
end 