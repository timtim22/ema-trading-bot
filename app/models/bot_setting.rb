class BotSetting < ApplicationRecord
  belongs_to :user
  
  # Serialize symbols as JSON array
  serialize :symbols, coder: JSON
  
  # Validations
  validates :timeframe, presence: true, inclusion: { in: %w[1m 5m 15m 30m 1h 4h 1d] }
  validates :profit_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :loss_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :confirmation_bars, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :symbols, presence: true
  
  # Callbacks
  before_validation :ensure_symbols_is_array
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
  
  AVAILABLE_SYMBOLS = %w[AAPL MSFT GOOG AMZN TSLA NVDA META NFLX].freeze
  
  # Class methods
  def self.for_user(user)
    find_or_create_by(user: user)
  end
  
  # Instance methods
  def symbols_list
    symbols.is_a?(Array) ? symbols : []
  end
  
  def symbols_display
    symbols_list.join(', ')
  end
  
  def timeframe_display
    TIMEFRAMES.find { |_, value| value == timeframe }&.first || timeframe
  end
  
  private
  
  def ensure_symbols_is_array
    if symbols.is_a?(String)
      begin
        self.symbols = JSON.parse(symbols)
      rescue JSON::ParserError
        self.symbols = [symbols]
      end
    elsif symbols.nil?
      self.symbols = ['AAPL']
    end
  end
  
  def set_defaults
    self.symbols ||= ['AAPL']
    self.timeframe ||= '5m'
    self.profit_percentage ||= 2.0
    self.loss_percentage ||= 1.0
    self.confirmation_bars ||= 3
  end
end
