# Alpaca Trading API Configuration
# Supports both paper trading (simulation) and live trading environments

# Determine if we're using paper trading
PAPER_TRADING = ENV.fetch('PAPER_TRADING', 'true').downcase == 'true'

# Set the appropriate endpoint based on paper trading mode
ALPACA_ENDPOINT = if PAPER_TRADING
                    'https://paper-api.alpaca.markets'
                  else
                    'https://api.alpaca.markets'
                  end

Alpaca::Trade::Api.configure do |config|
  config.endpoint   = ALPACA_ENDPOINT
  config.key_id     = ENV['ALPACA_API_KEY_ID']
  config.key_secret = ENV['ALPACA_API_SECRET_KEY']
end

ALPACA_CLIENT = Alpaca::Trade::Api::Client.new

# Log the current trading mode for clarity
Rails.logger.info "Alpaca Trading Mode: #{PAPER_TRADING ? 'PAPER TRADING (Simulation)' : 'LIVE TRADING'}"
Rails.logger.info "Alpaca Endpoint: #{ALPACA_ENDPOINT}"

# Paper trading configuration constants
if PAPER_TRADING
  PAPER_TRADING_INITIAL_BALANCE = ENV.fetch('PAPER_TRADING_BALANCE', '100000').to_f
  Rails.logger.info "Paper Trading Initial Balance: $#{PAPER_TRADING_INITIAL_BALANCE.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse}"
end
