class BotState < ApplicationRecord
  validates :symbol, presence: true, uniqueness: true
  validates :running, inclusion: { in: [true, false] }
  
  scope :running, -> { where(running: true) }
  scope :stopped, -> { where(running: false) }
  
  # Class methods for easy access
  def self.for_symbol(symbol)
    find_or_create_by(symbol: symbol)
  end
  
  def self.running?(symbol = 'AAPL')
    for_symbol(symbol).running?
  end
  
  def self.start!(symbol = 'AAPL')
    bot_state = for_symbol(symbol)
    bot_state.update!(
      running: true,
      last_run_at: Time.current,
      error_message: nil
    )
    bot_state
  end
  
  def self.stop!(symbol = 'AAPL')
    bot_state = for_symbol(symbol)
    bot_state.update!(running: false)
    bot_state
  end
  
  def self.log_error!(symbol, error_message)
    bot_state = for_symbol(symbol)
    bot_state.update!(
      running: false,
      error_message: error_message
    )
    bot_state
  end
  
  # Instance methods
  def start!
    update!(
      running: true,
      last_run_at: Time.current,
      error_message: nil
    )
  end
  
  def stop!
    update!(running: false)
  end
  
  def status_text
    running? ? 'Running' : 'Stopped'
  end
  
  def status_color
    if error_message.present?
      'red'
    elsif running?
      'green'
    else
      'gray'
    end
  end
  
  def last_run_display
    return 'Never' unless last_run_at
    
    if last_run_at > 1.minute.ago
      "#{time_ago_in_words_helper(last_run_at)} ago"
    else
      last_run_at.strftime('%H:%M:%S')
    end
  end
  
  private
  
  def time_ago_in_words_helper(time)
    distance = Time.current - time
    case distance
    when 0..59
      "#{distance.to_i} seconds"
    when 60..3599
      "#{(distance / 60).to_i} minutes"
    else
      "#{(distance / 3600).to_i} hours"
    end
  end
end
