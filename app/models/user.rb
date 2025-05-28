class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
         
  has_many :positions, dependent: :destroy
  has_many :trading_signals, dependent: :destroy
  has_one :bot_setting, dependent: :destroy
  
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
    bot_configuration.symbols_list
  end
end
