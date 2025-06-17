FactoryBot.define do
  factory :bot_setting do
    association :user
    
    timeframe { '5m' }
    profit_percentage { 2.0 }
    loss_percentage { 1.0 }
    confirmation_bars { 3 }
    
    # Traits for different configurations
    trait :aggressive do
      profit_percentage { 3.0 }
      loss_percentage { 2.0 }
      confirmation_bars { 2 }
    end
    
    trait :conservative do
      profit_percentage { 1.5 }
      loss_percentage { 0.5 }
      confirmation_bars { 5 }
    end
    
    trait :one_minute do
      timeframe { '1m' }
    end
    
    trait :hourly do
      timeframe { '1h' }
    end
  end
end 