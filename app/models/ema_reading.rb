class EmaReading < ApplicationRecord
  # Validations
  validates :symbol, presence: true
  validates :period, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :value, presence: true, numericality: true
  validates :timestamp, presence: true
  
  # Scopes
  scope :for_symbol, ->(symbol) { where(symbol: symbol) }
  scope :for_period, ->(period) { where(period: period) }
  scope :recent_first, -> { order(timestamp: :desc) }
  scope :oldest_first, -> { order(timestamp: :asc) }
  
  # Class methods
  def self.latest_ema_crossover(symbol)
    ema5 = for_symbol(symbol).for_period(5).recent_first.limit(3)
    ema8 = for_symbol(symbol).for_period(8).recent_first.limit(3)
    
    # Check if we have enough data
    return nil if ema5.count < 3 || ema8.count < 3
    
    # Check for crossover condition (EMA5 > EMA8) for last 3 bars
    crossover = true
    3.times do |i|
      crossover = false unless ema5[i].value > ema8[i].value
    end
    
    crossover ? ema5.first.timestamp : nil
  end
end
