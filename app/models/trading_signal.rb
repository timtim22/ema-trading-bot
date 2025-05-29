class TradingSignal < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :symbol, presence: true, length: { maximum: 10 }
  validates :signal_type, presence: true, inclusion: { in: %w[buy sell] }
  validates :price, :ema5, :ema8, :ema22, presence: true, numericality: { greater_than: 0 }
  validates :timestamp, presence: true
  
  # Scopes
  scope :recent_first, -> { order(timestamp: :desc) }
  scope :for_symbol, ->(symbol) { where(symbol: symbol) }
  scope :for_user, ->(user) { where(user: user) }
  scope :buy_signals, -> { where(signal_type: 'buy') }
  scope :sell_signals, -> { where(signal_type: 'sell') }
  scope :recent, ->(limit = 5) { recent_first.limit(limit) }
  
  # Helper methods
  def buy_signal?
    signal_type == 'buy'
  end
  
  def sell_signal?
    signal_type == 'sell'
  end
  
  def formatted_price
    "$#{price.to_f.round(2)}"
  end
  
  def formatted_time
    Time.at(timestamp).strftime("%H:%M")
  end
  
  def formatted_date_time
    Time.at(timestamp).strftime("%m/%d %H:%M")
  end
  
  def signal_badge_class
    buy_signal? ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
  end
  
  def signal_icon
    buy_signal? ? '📈' : '📉'
  end
  
  def signal_description
    "#{signal_icon} #{signal_type.capitalize} (EMA Crossover)"
  end
  
  # Class methods
  def self.detect_crossover_signal(symbol, current_emas, previous_emas, current_price, user)
    return nil unless current_emas && previous_emas
    
    # Get user-specific settings
    user_settings = BotSetting.for_user(user)
    confirmation_bars = user_settings.confirmation_bars || 3
    
    # For now, we use simple crossover detection since we only have current and previous EMAs
    # In a full implementation, we would need historical EMA data for confirmation_bars
    # This is a simplified version that detects immediate crossovers
    
    # Buy signal: EMA5 > EMA8 > EMA22 (bullish alignment)
    # Sell signal: EMA5 < EMA8 < EMA22 (bearish alignment)
    
    current_bullish = current_emas[:ema5] > current_emas[:ema8] && current_emas[:ema8] > current_emas[:ema22]
    current_bearish = current_emas[:ema5] < current_emas[:ema8] && current_emas[:ema8] < current_emas[:ema22]
    
    previous_bullish = previous_emas[:ema5] > previous_emas[:ema8] && previous_emas[:ema8] > previous_emas[:ema22]
    previous_bearish = previous_emas[:ema5] < previous_emas[:ema8] && previous_emas[:ema8] < previous_emas[:ema22]
    
    signal_type = nil
    
    # Detect crossover from bearish to bullish (buy signal)
    if current_bullish && !previous_bullish
      signal_type = 'buy'
      Rails.logger.info "TradingSignal: Buy signal detected for #{symbol} (user #{user.id}, confirmation_bars=#{confirmation_bars})"
    # Detect crossover from bullish to bearish (sell signal)  
    elsif current_bearish && !previous_bearish
      signal_type = 'sell'
      Rails.logger.info "TradingSignal: Sell signal detected for #{symbol} (user #{user.id}, confirmation_bars=#{confirmation_bars})"
    end
    
    if signal_type
      create!(
        symbol: symbol,
        signal_type: signal_type,
        price: current_price,
        ema5: current_emas[:ema5],
        ema8: current_emas[:ema8],
        ema22: current_emas[:ema22],
        timestamp: Time.current,
        user: user
      )
    end
  rescue => e
    Rails.logger.error "Error detecting crossover signal for #{symbol}: #{e.message}"
    nil
  end
end
