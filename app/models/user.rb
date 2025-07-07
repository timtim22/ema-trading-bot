class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
         
  has_many :positions, dependent: :destroy
  has_many :trading_signals, dependent: :destroy
  has_one :bot_setting, dependent: :destroy
  has_many :tracked_symbols, dependent: :destroy
  has_many :activity_logs, dependent: :destroy
  
  # Callbacks
  after_create :create_default_tracked_symbols
  
  def active_positions
    positions.active
  end
  
  def completed_positions
    positions.completed
  end
  
  def total_profit_loss
    positions.completed.sum(:profit_loss)
  end
  
  def recent_trading_signals(limit = 5)
    trading_signals.recent(limit)
  end
  
  def bot_configuration
    bot_setting || build_bot_setting
  end
  
  def configured_symbols
    # Use TrackedSymbol model if available, fallback to default symbols
    begin
      active_tracked_symbols = tracked_symbols.active.pluck(:symbol)
      active_tracked_symbols.presence || ['AAPL']
    rescue => e
      Rails.logger.error "User#configured_symbols error for user #{id}: #{e.message}"
      ['AAPL'] # Safe fallback
    end
  end
  
  def active_tracked_symbols
    tracked_symbols.active.by_symbol
  end
  
  def all_tracked_symbols
    tracked_symbols.by_symbol
  end
  
  private
  
  def create_default_tracked_symbols
    TrackedSymbol.create_default_symbols_for_user(self)
  end
end
