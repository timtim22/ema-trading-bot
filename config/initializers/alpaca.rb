Alpaca::Trade::Api.configure do |config|
config.endpoint   = 'https://paper-api.alpaca.markets'
config.key_id     = ENV['ALPACA_API_KEY_ID']
config.key_secret = ENV['ALPACA_API_SECRET_KEY']
end

ALPACA_CLIENT = Alpaca::Trade::Api::Client.new
