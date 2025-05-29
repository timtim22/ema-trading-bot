class Position < ApplicationRecord
  belongs_to :user
  
  # Enums
  enum :status, {
    open: 'open',
    closed_profit: 'closed_profit',
    closed_loss: 'closed_loss',
    pending: 'pending',
    cancelled: 'cancelled',
    error: 'error'
  }, default: 'open'
  
  # Validations
  validates :symbol, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :entry_price, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :exit_price, numericality: { greater_than: 0, allow_nil: true }
  
  # Scopes
  scope :active, -> { where(status: 'open') }
  scope :open, -> { where(status: 'open') }
  scope :completed, -> { where.not(status: ['open', 'pending']) }
  scope :profitable, -> { where(status: 'closed_profit') }
  scope :for_symbol, ->(symbol) { where(symbol: symbol) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :user_scope, ->(user) { user.present? ? where(user: user) : all }
  scope :for_user, ->(user) { where(user: user) }
  
  # Callbacks
  before_save :calculate_profit_loss, if: :calculating_profit_loss?
  
  # Methods
  def close(exit_price, reason = nil)
    self.exit_price = exit_price
    self.exit_time = Time.current
    self.exit_reason = reason
    
    # Determine if profit or loss
    if exit_price > entry_price
      self.status = 'closed_profit'
    else
      self.status = 'closed_loss'
    end
    
    save
  end
  
  def close_manually!(exit_price = nil)
    price = exit_price || current_price || entry_price
    close(price, 'manual_close')
  end
  
  def update_current_price!(price)
    update!(current_price: price)
  end
  
  def unrealized_pnl
    return 0 unless current_price.present? && entry_price.present?
    
    shares = amount / entry_price
    current_value = shares * current_price
    entry_value = amount
    
    current_value - entry_value
  end
  
  def unrealized_pnl_percentage
    return 0 unless current_price.present? && entry_price.present?
    
    ((current_price - entry_price) / entry_price * 100).round(2)
  end
  
  def profit_loss_percentage
    return 0 unless exit_price.present? && entry_price.present?
    
    ((exit_price - entry_price) / entry_price * 100).round(2)
  end
  
  def realized_pnl_color_class
    return 'text-gray-600' unless profit_loss.present?
    
    if profit_loss > 0
      'text-green-600'
    elsif profit_loss < 0
      'text-red-600'
    else
      'text-gray-600'
    end
  end
  
  def formatted_realized_pnl
    return '0.00%' unless profit_loss_percentage
    
    pnl = profit_loss_percentage
    sign = pnl >= 0 ? '+' : ''
    "#{sign}#{pnl}%"
  end
  
  def pnl_color_class
    pnl = unrealized_pnl_percentage
    if pnl > 0
      'text-green-600'
    elsif pnl < 0
      'text-red-600'
    else
      'text-gray-600'
    end
  end
  
  def formatted_pnl
    pnl = unrealized_pnl_percentage
    sign = pnl >= 0 ? '+' : ''
    "#{sign}#{pnl}%"
  end
  
  def shares_quantity
    return 0 unless amount.present? && entry_price.present?
    (amount / entry_price).round(4)
  end
  
  private
  
  def calculating_profit_loss?
    exit_price.present? && entry_price.present? && exit_price_changed?
  end
  
  def calculate_profit_loss
    return unless exit_price.present? && entry_price.present?
    
    shares = amount / entry_price
    entry_value = amount
    exit_value = shares * exit_price
    
    self.profit_loss = exit_value - entry_value
  end
end
