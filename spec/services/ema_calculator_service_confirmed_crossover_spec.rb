require 'rails_helper'

RSpec.describe EmaCalculatorService, '.confirmed_crossover?', type: :service do
  describe 'Ticket T3: 3-Bar Confirmation Logic' do
    context 'with exact acceptance criteria from Ticket T3' do
      it 'returns true when bars -4:1 are false and bars -3:0 are true' do
        # Create test data per EXACT Ticket T3 specification:
        # "Supply arrays where bars −4:1 are false, bars −3:0 are true → returns true"
        # This means: bar -4 is false, bars -3, -2, -1 are true
        
        ema5_values = [8.0, 15.0, 16.0, 17.0]   # 4 elements
        ema8_values = [12.0, 11.0, 11.5, 12.0]  # 4 elements
        
        # Verify our test setup matches Ticket T3 exactly:
        # Bar -4 (index 0): EMA5=8.0 <= EMA8=12.0 ✓ (false - crossover prerequisite)
        # Bar -3 (index 1): EMA5=15.0 > EMA8=11.0 ✓ (true - crossover happens)
        # Bar -2 (index 2): EMA5=16.0 > EMA8=11.5 ✓ (true - confirmation 1)
        # Bar -1 (index 3): EMA5=17.0 > EMA8=12.0 ✓ (true - confirmation 2)
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_truthy, "Should return true when crossover followed by 3 confirmations"
      end
      
      it 'returns false when all bars are true (no crossover, just continuation)' do
        # All bars show EMA5 > EMA8, so no actual crossover occurred
        ema5_values = [15.0, 16.0, 17.0, 18.0, 19.0]
        ema8_values = [10.0, 11.0, 12.0, 13.0, 14.0]
        
        # Verify: all conditions are true, no crossover
        # Bar -4: 15.0 > 10.0 ✓ (true)
        # Bar -3: 16.0 > 11.0 ✓ (true)
        # Bar -2: 17.0 > 12.0 ✓ (true)
        # Bar -1: 18.0 > 13.0 ✓ (true)
        # Bar  0: 19.0 > 14.0 ✓ (true)
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_falsey, "Should return false when no crossover occurred (all bars true)"
      end
      
      it 'returns false when only 2 bars are true (insufficient confirmation)' do
        # Only last 2 bars satisfy EMA5 > EMA8, need 3 for confirmation
        ema5_values = [8.0, 9.0, 10.0, 15.0, 16.0]
        ema8_values = [12.0, 13.0, 14.0, 12.0, 13.0]
        
        # Verify: only last 2 are true
        # Bar -4: 8.0 <= 12.0 ✓ (false)
        # Bar -3: 9.0 <= 13.0 ✓ (false)
        # Bar -2: 10.0 <= 14.0 ✓ (false)
        # Bar -1: 15.0 > 12.0 ✓ (true) - only 2 confirmations
        # Bar  0: 16.0 > 13.0 ✓ (true)
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_falsey, "Should return false when only 2 bars confirm (need 3)"
      end
    end
    
    context 'edge cases and boundary conditions' do
      it 'returns false when arrays are too short (less than 3 elements)' do
        ema5_values = [15.0, 16.0]  # Only 2 elements
        ema8_values = [10.0, 11.0]
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_falsey, "Should return false with insufficient data"
      end
      
      it 'returns false when only first array is too short' do
        ema5_values = [15.0, 16.0]  # Only 2 elements
        ema8_values = [10.0, 11.0, 12.0, 13.0, 14.0]  # 5 elements
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_falsey, "Should return false when EMA5 array too short"
      end
      
      it 'returns false when only second array is too short' do
        ema5_values = [10.0, 11.0, 12.0, 13.0, 14.0]  # 5 elements
        ema8_values = [15.0, 16.0]  # Only 2 elements
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_falsey, "Should return false when EMA8 array too short"
      end
      
      it 'handles exact minimum length (3 elements) without prior crossover check' do
        # With exactly 3 elements, can't check 4th bar back, so should pass based on 3-bar check
        ema5_values = [15.0, 16.0, 17.0]  # All > corresponding EMA8
        ema8_values = [10.0, 11.0, 12.0]
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        # Based on implementation: if not enough history, returns true based on 3-bar check
        expect(result).to be_truthy, "Should return true with minimum data when all 3 bars confirm"
      end
      
      it 'handles equal EMA values at crossover point' do
        # Test boundary case where EMAs are equal
        ema5_values = [10.0, 12.0, 15.0, 16.0, 17.0]
        ema8_values = [12.0, 12.0, 11.0, 11.5, 12.0]  # Equal at crossover point
        
        # Bar -5: 10.0 <= 12.0 ✓ (false)
        # Bar -4: 12.0 <= 12.0 ✓ (false - equal EMAs are valid crossover prerequisite)
        # Bar -3: 15.0 > 11.0 ✓ (true - crossover)
        # Bar -2: 16.0 > 11.5 ✓ (true - confirmation 1)
        # Bar -1: 17.0 > 12.0 ✓ (true - confirmation 2)
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values)
        
        expect(result).to be_truthy, "Should return true when EMAs equal before crossover (valid signal)"
      end
    end
    
    context 'with EMA-22 validation (optional 3-parameter version)' do
      it 'returns true when both EMA5>EMA8 and EMA8>EMA22 conditions are met' do
        ema5_values = [8.0, 15.0, 16.0, 17.0]     # 4 elements  
        ema8_values = [12.0, 13.0, 14.0, 15.0]    # 4 elements
        ema22_values = [14.0, 11.0, 12.0, 13.0]   # 4 elements
        
        # Verify setup:
        # Bar -4: EMA5 <= EMA8 (8.0 <= 12.0) AND EMA8 <= EMA22 (12.0 <= 14.0) ✓ (prerequisites)
        # Bar -3: EMA5 > EMA8 (15.0 > 13.0) AND EMA8 > EMA22 (13.0 > 11.0) ✓ (crossover)
        # Bar -2: EMA5 > EMA8 (16.0 > 14.0) AND EMA8 > EMA22 (14.0 > 12.0) ✓ (confirm 1)
        # Bar -1: EMA5 > EMA8 (17.0 > 15.0) AND EMA8 > EMA22 (15.0 > 13.0) ✓ (confirm 2)
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values, ema22_values)
        
        expect(result).to be_truthy, "Should return true when both EMA5>EMA8 and EMA8>EMA22 conditions met"
      end
      
      it 'returns false when EMA5>EMA8 confirmed but EMA8<=EMA22' do
        ema5_values = [8.0, 15.0, 16.0, 17.0]     # 4 elements
        ema8_values = [12.0, 13.0, 14.0, 15.0]    # 4 elements  
        ema22_values = [14.0, 15.0, 16.0, 17.0]   # 4 elements - EMA22 too high
        
        # EMA5 > EMA8 conditions met, but EMA8 <= EMA22 for last bars
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values, ema22_values)
        
        expect(result).to be_falsey, "Should return false when EMA8 <= EMA22 despite EMA5>EMA8"
      end
      
      it 'handles insufficient EMA22 data gracefully' do
        ema5_values = [8.0, 15.0, 16.0, 17.0]   # 4 elements
        ema8_values = [12.0, 13.0, 14.0, 15.0]  # 4 elements
        ema22_values = [11.0, 12.0]             # Only 2 values, need 3
        
        result = described_class.confirmed_crossover?(ema5_values, ema8_values, ema22_values)
        
        # Should still work without EMA22 check when insufficient data
        expect(result).to be_truthy, "Should ignore EMA22 check when insufficient EMA22 data"
      end
    end
  end
end 