class BotSetting < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :timeframe, presence: true, inclusion: { in: %w[1m 5m 15m 30m 1h 4h 1d] }
  validates :profit_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :loss_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :confirmation_bars, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10 }

  # Custom validation to ensure user has at least one active tracked symbol
  validate :user_has_active_symbols
  
  # Callbacks
  before_validation :set_defaults, on: :create
  
  # Available options
  TIMEFRAMES = [
    ['1 Minute', '1m'],
    ['5 Minutes', '5m'],
    ['15 Minutes', '15m'],
    ['30 Minutes', '30m'],
    ['1 Hour', '1h'],
    ['4 Hours', '4h'],
    ['1 Day', '1d']
  ].freeze
  
  # Class methods
  def self.for_user(user)
    find_or_create_by(user: user)
  end
  
  # Instance methods
  def timeframe_display
    TIMEFRAMES.find { |_, value| value == timeframe }&.first || timeframe
  end
  
  private
  
  def set_defaults
    self.timeframe ||= '5m'
    self.profit_percentage ||= 2.0
    self.loss_percentage ||= 1.0
    self.confirmation_bars ||= 3
  end
  
  def user_has_active_symbols
    return unless user # Skip validation if user is not set (during creation)
    
    if user.active_tracked_symbols.empty?
      errors.add(:base, "Please select at least one trading symbol from the Symbol Management section")
    end
  end
end
