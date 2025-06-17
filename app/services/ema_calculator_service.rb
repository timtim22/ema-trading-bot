# frozen_string_literal: true

# Service to calculate Exponential Moving Averages (EMAs)
class EmaCalculatorService
  # Calculate an EMA for a given period
  #
  # @param prices [Array<Float>] array of price data (oldest first)
  # @param period [Integer] the EMA period (e.g., 5 for EMA-5)
  # @param smoothing [Float] the smoothing factor (default: 2)
  # @return [Float] the calculated EMA value for the most recent price
  def self.calculate_ema(prices, period, smoothing = 2)
    return nil if prices.empty? || prices.length < period
    
    # Use SMA as the initial EMA value
    ema = prices.first(period).sum / period.to_f
    
    # Calculate the multiplier
    multiplier = smoothing / (period + 1.0)
    
    # Calculate EMA for each price starting from period
    prices[period..-1].each do |price|
      ema = (price - ema) * multiplier + ema
    end
    
    ema
  end
  
  # Calculate EMA values for multiple periods
  #
  # @param prices [Array<Float>] array of price data (oldest first)
  # @param periods [Array<Integer>] array of periods to calculate (e.g., [5, 8, 22])
  # @return [Hash] hash containing EMA values and sequences for each period
  def self.calculate_ema_series(prices, periods = [5, 8, 22])
    return {} if prices.empty?
    
    max_period = periods.max
    return {} if prices.length < max_period
    
    result = {
      # Initialize with empty arrays for each period
      values: {}
    }
    
    # Initialize value arrays for each period
    periods.each do |period|
      result[:values][period] = []
    end
    
    # Calculate EMA series for each period independently
    periods.each do |period|
      # Start calculating as soon as we have enough data for this period
      (period..prices.length).each do |i|
        window = prices[0...i]
        ema_value = calculate_ema(window, period)
        result[:values][period] << ema_value if ema_value
      end
    end
    
    # Add individual latest values for convenience
    periods.each do |period|
      result[period] = result[:values][period].last
    end
    
    result
  end
  
  # Calculate both EMA-5, EMA-8, and EMA-22 values
  # This is maintained for backwards compatibility
  # It's recommended to use calculate_ema_series instead
  #
  # @param prices [Array<Float>] array of price data (oldest first)
  # @return [Hash] hash containing EMA values
  def self.calculate_emas(prices)
    result = calculate_ema_series(prices)
    
    # Handle case when prices array is too short (result is empty)
    if result.empty?
      return {
        ema5: nil,
        ema8: nil,
        ema22: nil
      }
    end
    
    {
      ema5: result[5],
      ema8: result[8],
      ema22: result[22]
    }
  end
  
  # Check if both EMA-5 > EMA-8 and EMA-8 > EMA-22 (or EMA-5 > EMA-22)
  # This confirms we're in a strong uptrend at multiple timeframes
  #
  # @param ema5 [Float] the EMA-5 value
  # @param ema8 [Float] the EMA-8 value
  # @param ema22 [Float] the EMA-22 value
  # @return [Boolean] true if both conditions are met
  def self.uptrend?(ema5, ema8, ema22)
    ema5 > ema8 && ema8 > ema22
  end
  
  # Check if EMA-5 is crossing above EMA-8
  #
  # @param ema5_values [Array<Float>] array of EMA-5 values (oldest first)
  # @param ema8_values [Array<Float>] array of EMA-8 values (oldest first)
  # @return [Boolean] true if EMA-5 crossed above EMA-8 in the most recent period
  def self.crossover?(ema5_values, ema8_values)
    return false if ema5_values.length < 2 || ema8_values.length < 2
    
    # Previous candle: EMA-5 was below EMA-8 (or equal)
    previous_ema5 = ema5_values[-2]
    previous_ema8 = ema8_values[-2]
    previous_condition = previous_ema5 <= previous_ema8
    
    # Current candle: EMA-5 is above EMA-8
    current_ema5 = ema5_values[-1]
    current_ema8 = ema8_values[-1]
    current_condition = current_ema5 > current_ema8
    
    # Crossover occurs when previous condition was false and current is true
    previous_condition && current_condition
  end
  
  # Check if there's a confirmed crossover with additional confirmation from EMA-22
  # - 3 consecutive bars with EMA-5 > EMA-8
  # - 3 consecutive bars with EMA-8 > EMA-22 (if EMA-22 provided)
  # - The bar immediately before the 3-bar confirmation was EMA-5 <= EMA-8 (actual crossover)
  #
  # @param ema5_values [Array<Float>] array of recent EMA-5 values (oldest first)
  # @param ema8_values [Array<Float>] array of recent EMA-8 values (oldest first)
  # @param ema22_values [Array<Float>] array of recent EMA-22 values (oldest first)
  # @return [Boolean] true if there's a confirmed crossover
  def self.confirmed_crossover?(ema5_values, ema8_values, ema22_values = nil)
    return false if ema5_values.length < 3 || ema8_values.length < 3
    
    # Check if the last 3 values show EMA-5 > EMA-8 (3-bar confirmation)
    3.times do |i|
      return false unless ema5_values[-(i+1)] > ema8_values[-(i+1)]
    end
    
    # If EMA-22 values are provided, check that EMA-8 > EMA-22 for 3 consecutive bars
    if ema22_values && ema22_values.length >= 3
      3.times do |i|
        return false unless ema8_values[-(i+1)] > ema22_values[-(i+1)]
      end
    end
    
    # Check if there was a crossover before the 3-bar confirmation
    # We need to check the bar immediately before the 3-bar confirmation period
    # The 3-bar confirmation covers indices [-3, -2, -1], so we check index -4
    if ema5_values.length >= 4 && ema8_values.length >= 4
      # The bar before the 3-bar confirmation should show EMA-5 <= EMA-8
      pre_confirmation_ema5 = ema5_values[-4]
      pre_confirmation_ema8 = ema8_values[-4]
      return pre_confirmation_ema5 <= pre_confirmation_ema8
    end
    
    # If we don't have enough history to verify the actual crossover,
    # return true based on the 3-bar check (this covers the minimum case)
    true
  end
end 