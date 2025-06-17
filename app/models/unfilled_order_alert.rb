class UnfilledOrderAlert < ApplicationRecord
  belongs_to :position
  
  validates :order_id, presence: true
  validates :timeout_duration, presence: true, numericality: { greater_than: 0 }
  
  # Prevent duplicate alerts for the same position
  validates :position_id, uniqueness: { scope: :order_id }
  
  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { joins(:position).where(positions: { user: user }) }
  
  def timeout_minutes
    (timeout_duration / 60.0).round(1)
  end
  
  def formatted_timeout
    if timeout_duration < 60
      "#{timeout_duration.to_i}s"
    elsif timeout_duration < 3600
      "#{timeout_minutes}m"
    else
      hours = (timeout_duration / 3600.0).round(1)
      "#{hours}h"
    end
  end
end 