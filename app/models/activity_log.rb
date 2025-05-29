# frozen_string_literal: true

# Model to store system activity logs for the trading bot
class ActivityLog < ApplicationRecord
  include ActionView::Helpers::DateHelper
  
  belongs_to :user, optional: true
  
  # Event types for filtering
  TYPES = %w[
    fetch
    signal
    order
    error
    info
    warning
    bot_start
    bot_stop
    position_open
    position_close
    market_update
    system
  ].freeze
  
  # Log levels for severity
  LEVELS = %w[info warning error].freeze
  
  validates :event_type, presence: true, inclusion: { in: TYPES }
  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :message, presence: true
  validates :occurred_at, presence: true
  
  # Scopes for filtering
  scope :by_type, ->(type) { where(event_type: type) if type.present? }
  scope :by_level, ->(level) { where(level: level) if level.present? }
  scope :by_user, ->(user) { where(user: user) if user.present? }
  scope :recent, -> { order(occurred_at: :desc) }
  scope :today, -> { where(occurred_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(occurred_at: 1.week.ago..Time.current) }
  
  # Class methods for logging different types of events
  def self.log_fetch(symbol, success: true, message: nil, user: nil, details: {})
    create!(
      event_type: 'fetch',
      level: success ? 'info' : 'error',
      message: message || "Market data fetch for #{symbol}",
      symbol: symbol,
      user: user,
      details: details.merge(success: success),
      occurred_at: Time.current
    )
  end
  
  def self.log_signal(symbol, signal_type, price, user: nil, details: {})
    create!(
      event_type: 'signal',
      level: 'info',
      message: "#{signal_type.upcase} signal generated for #{symbol} at $#{price}",
      symbol: symbol,
      user: user,
      details: details.merge(signal_type: signal_type, price: price),
      occurred_at: Time.current
    )
  end
  
  def self.log_order(symbol, order_type, amount, success: true, message: nil, user: nil, details: {})
    create!(
      event_type: 'order',
      level: success ? 'info' : 'error',
      message: message || "#{order_type.upcase} order for #{symbol} (#{amount})",
      symbol: symbol,
      user: user,
      details: details.merge(order_type: order_type, amount: amount, success: success),
      occurred_at: Time.current
    )
  end
  
  def self.log_error(message, context: nil, user: nil, details: {})
    create!(
      event_type: 'error',
      level: 'error',
      message: message,
      user: user,
      details: details.merge(context: context),
      occurred_at: Time.current
    )
  end
  
  def self.log_info(message, event_type: 'info', user: nil, details: {})
    create!(
      event_type: event_type,
      level: 'info',
      message: message,
      user: user,
      details: details,
      occurred_at: Time.current
    )
  end
  
  def self.log_warning(message, event_type: 'warning', user: nil, details: {})
    create!(
      event_type: event_type,
      level: 'warning',
      message: message,
      user: user,
      details: details,
      occurred_at: Time.current
    )
  end
  
  def self.log_bot_event(action, user: nil, message: nil, details: {})
    create!(
      event_type: "bot_#{action}",
      level: 'info',
      message: message || "Trading bot #{action}",
      user: user,
      details: details,
      occurred_at: Time.current
    )
  end
  
  def self.log_position_event(action, symbol, user: nil, details: {})
    create!(
      event_type: "position_#{action}",
      level: 'info',
      message: "Position #{action} for #{symbol}",
      symbol: symbol,
      user: user,
      details: details,
      occurred_at: Time.current
    )
  end
  
  def self.log_market_update(symbol, price, user: nil, details: {})
    create!(
      event_type: 'market_update',
      level: 'info',
      message: "Market update for #{symbol}: $#{price}",
      symbol: symbol,
      user: user,
      details: details.merge(price: price),
      occurred_at: Time.current
    )
  end
  
  # Instance methods
  def level_badge_class
    case level
    when 'info'
      'bg-blue-100 text-blue-800'
    when 'warning'
      'bg-yellow-100 text-yellow-800'
    when 'error'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
  
  def type_badge_class
    case event_type
    when 'fetch'
      'bg-green-100 text-green-800'
    when 'signal'
      'bg-purple-100 text-purple-800'
    when 'order'
      'bg-orange-100 text-orange-800'
    when 'error'
      'bg-red-100 text-red-800'
    when 'bot_start', 'bot_stop'
      'bg-indigo-100 text-indigo-800'
    when 'position_open', 'position_close'
      'bg-pink-100 text-pink-800'
    when 'market_update'
      'bg-teal-100 text-teal-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
  
  def formatted_occurred_at
    occurred_at.strftime("%m/%d/%Y %I:%M:%S %p")
  end
  
  def time_ago
    distance_of_time_in_words(occurred_at, Time.current, include_seconds: true) + " ago"
  end
end 