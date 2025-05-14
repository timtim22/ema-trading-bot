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
  scope :completed, -> { where.not(status: ['open', 'pending']) }
  scope :profitable, -> { where(status: 'closed_profit') }
  scope :for_symbol, ->(symbol) { where(symbol: symbol) }
  scope :recent_first, -> { order(created_at: :desc) }
  
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
