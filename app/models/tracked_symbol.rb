class TrackedSymbol < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :symbol, presence: true, 
                     length: { maximum: 10 },
                     format: { with: /\A[A-Z]+\z/, message: "must contain only uppercase letters" },
                     uniqueness: { scope: :user_id, message: "is already being tracked" }
  validates :active, inclusion: { in: [true, false] }
  
  # Callbacks
  before_validation :upcase_symbol
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_symbol, -> { order(:symbol) }
  
  # Available symbols that can be tracked
  AVAILABLE_SYMBOLS = %w[AAPL MSFT GOOG GOOGL AMZN TSLA NVDA META NFLX ORCL CRM ADBE PYPL INTC AMD QCOM].freeze
  
  # Class methods
  def self.available_symbols
    AVAILABLE_SYMBOLS
  end
  
  def self.for_user_active_symbols(user)
    for_user(user).active.pluck(:symbol)
  end
  
  def self.create_default_symbols_for_user(user)
    return if for_user(user).exists?
    
    # Create default symbols for new users
    default_symbols = %w[AAPL NVDA MSFT]
    default_symbols.each do |symbol|
      create!(user: user, symbol: symbol, active: true)
    end
  end
  
  # Instance methods
  def toggle_active!
    update!(active: !active)
  end
  
  def deactivate!
    update!(active: false)
  end
  
  def activate!
    update!(active: true)
  end
  
  private
  
  def upcase_symbol
    self.symbol = symbol&.upcase
  end
end
