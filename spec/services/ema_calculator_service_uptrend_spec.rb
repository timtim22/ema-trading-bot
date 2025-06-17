require 'rails_helper'

RSpec.describe EmaCalculatorService, '.uptrend?', type: :service do
  describe 'Ticket T4: Uptrend Filter' do
    context 'with exact acceptance criteria from Ticket T4' do
      it 'returns true for (10,9,8) - perfect uptrend alignment' do
        # All EMAs aligned in proper uptrend order: EMA5 > EMA8 > EMA22
        ema5 = 10
        ema8 = 9
        ema22 = 8
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
        expect(result).to eq(true), "Should return true when EMA5 > EMA8 > EMA22 (#{ema5} > #{ema8} > #{ema22})"
      end
      
      it 'returns false for (10,9,11) - EMA22 too high' do
        # EMA5 > EMA8 but EMA8 < EMA22, not a strong uptrend
        ema5 = 10
        ema8 = 9
        ema22 = 11
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
        expect(result).to eq(false), "Should return false when EMA8 <= EMA22 (#{ema8} <= #{ema22})"
      end
      
      it 'returns false for (9,10,8) - EMA5 below EMA8' do
        # EMA8 > EMA22 but EMA5 < EMA8, not an uptrend
        ema5 = 9
        ema8 = 10
        ema22 = 8
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
        expect(result).to eq(false), "Should return false when EMA5 <= EMA8 (#{ema5} <= #{ema8})"
      end
    end
    
    context 'boundary conditions and edge cases' do
      it 'returns false when EMA5 equals EMA8' do
        # Equal values should not qualify as uptrend
        ema5 = 10
        ema8 = 10
        ema22 = 8
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
      
      it 'returns false when EMA8 equals EMA22' do
        # Equal values should not qualify as uptrend
        ema5 = 12
        ema8 = 10
        ema22 = 10
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
      
      it 'returns false when all EMAs are equal' do
        # All equal - flat market, not uptrend
        ema5 = 10
        ema8 = 10
        ema22 = 10
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
      
      it 'handles decimal values correctly' do
        # Real-world decimal EMA values
        ema5 = 105.75
        ema8 = 104.23
        ema22 = 103.10
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
      
      it 'handles very small differences' do
        # Tiny differences should still work
        ema5 = 100.001
        ema8 = 100.000
        ema22 = 99.999
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
    end
    
    context 'realistic trading scenarios' do
      it 'identifies strong bullish trend' do
        # Strong upward momentum across all timeframes
        ema5 = 152.50
        ema8 = 148.75
        ema22 = 142.30
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
      
      it 'rejects weak uptrend with lagging EMA22' do
        # Short-term bullish but long-term resistance
        ema5 = 100.50
        ema8 = 99.75
        ema22 = 101.25  # EMA22 above EMA8
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
      
      it 'rejects sideways market with EMA5 below EMA8' do
        # Sideways/bearish short-term movement
        ema5 = 98.25
        ema8 = 99.50
        ema22 = 97.80
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
      
      it 'handles downtrend scenario' do
        # Clear downtrend - all conditions fail
        ema5 = 95.00
        ema8 = 98.50
        ema22 = 102.75
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
    end
    
    context 'parameter validation' do
      it 'handles negative values' do
        # Edge case: negative EMA values (rare but possible)
        ema5 = -5
        ema8 = -8
        ema22 = -10
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
      
      it 'handles zero values' do
        # Edge case: zero values
        ema5 = 0
        ema8 = -1
        ema22 = -2
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
      
      it 'handles mixed positive/negative values' do
        # Mixed scenario
        ema5 = 5
        ema8 = 0
        ema22 = -3
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
    end
    
    context 'integration with trading logic' do
      it 'validates uptrend before confirming signals' do
        # This would be used in conjunction with crossover signals
        # Strong uptrend: good for trades
        ema5 = 110
        ema8 = 108
        ema22 = 105
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_truthy
      end
      
      it 'filters out weak signals in choppy markets' do
        # Choppy market: EMA22 resistance
        ema5 = 100.5
        ema8 = 100.2
        ema22 = 100.8  # Above EMA8
        
        result = described_class.uptrend?(ema5, ema8, ema22)
        
        expect(result).to be_falsey
      end
    end
  end
end 