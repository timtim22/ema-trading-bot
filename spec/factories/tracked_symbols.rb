FactoryBot.define do
  factory :tracked_symbol do
    association :user
    
    symbol { "AAPL" }
    active { true }
    
    # Traits for different states
    trait :inactive do
      active { false }
    end
    
    trait :msft do
      symbol { "MSFT" }
    end
    
    trait :nvda do
      symbol { "NVDA" }
    end
    
    trait :tsla do
      symbol { "TSLA" }
    end
  end
end 