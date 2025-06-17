FactoryBot.define do
  factory :position do
    association :user
    
    symbol { "AAPL" }
    amount { 1000.0 }
    entry_price { 150.0 }
    status { "open" }
    entry_time { Time.current }
    
    # Optional fields that may be set
    primary_order_id { nil }
    take_profit_order_id { nil }
    stop_loss_order_id { nil }
    fill_qty { nil }
    fill_notional { nil }
    current_price { nil }
    exit_price { nil }
    exit_reason { nil }
    exit_time { nil }
    profit_loss { nil }
    take_profit { nil }
    stop_loss { nil }
    
    # Factory traits for different states
    trait :with_order_ids do
      primary_order_id { "order_#{SecureRandom.hex(6)}" }
      take_profit_order_id { "tp_order_#{SecureRandom.hex(6)}" }
      stop_loss_order_id { "sl_order_#{SecureRandom.hex(6)}" }
    end
    
    trait :with_fill_data do
      fill_qty { 6.67 }
      fill_notional { amount }
    end
    
    trait :pending do
      status { "pending" }
    end
    
    trait :completed do
      status { "closed_profit" }
      exit_price { entry_price * 1.05 }
      exit_time { entry_time + 2.hours }
      exit_reason { "take_profit" }
      profit_loss { (exit_price - entry_price) * (amount / entry_price) }
    end
  end
end 