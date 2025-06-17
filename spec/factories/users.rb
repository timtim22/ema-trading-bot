FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    
    # Skip the callback that creates TrackedSymbols during tests
    # to avoid dependencies and control the creation manually
    after(:build) do |user|
      # Skip the create_default_tracked_symbols callback for tests
      user.define_singleton_method(:create_default_tracked_symbols) { }
    end
    
    # Create associated tracked_symbols and bot_setting after user creation
    after(:create) do |user|
      # Create default tracked symbols FIRST
      %w[AAPL MSFT NVDA].each do |symbol|
        FactoryBot.create(:tracked_symbol, user: user, symbol: symbol, active: true)
      end
      
      # Then create bot_setting (which validates presence of active symbols)
      unless user.bot_setting
        FactoryBot.create(:bot_setting, user: user)
      end
    end
  end
end 