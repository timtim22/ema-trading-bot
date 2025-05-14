class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
         
  has_many :positions, dependent: :destroy
  
  def active_positions
    positions.active
  end
  
  def completed_positions
    positions.completed
  end
  
  def total_profit_loss
    positions.completed.sum(:profit_loss)
  end
end
