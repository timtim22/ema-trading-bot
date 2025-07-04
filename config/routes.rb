require 'sidekiq/web'

Rails.application.routes.draw do
  # TrackedSymbols routes for symbol management
  resources :tracked_symbols, only: [:create, :destroy] do
    member do
      patch :toggle
    end
  end
  
  # Position management routes
  resources :positions, only: [:index, :show, :create] do
    member do
      post :close_manually
    end
  end
  
  # Trading history routes
  get '/trades/history', to: 'trading_history#index', as: 'trades_history'
  
  # Account overview routes
  get '/account', to: 'account#index', as: 'account'
  get '/account/refresh', to: 'account#refresh', as: 'account_refresh'
  
  # Activity logs routes
  get '/activity', to: 'activity#index', as: 'activity'
  get '/activity/stream', to: 'activity#stream', as: 'activity_stream'
  delete '/activity/clear', to: 'activity#clear', as: 'activity_clear'
  
  get "home/index"
  devise_for :users
  
  # Dashboard routes
  get '/dashboard', to: 'dashboard#index'
  
  # Bot state management routes
  post '/dashboard/start_bot', to: 'dashboard#start_bot'
  post '/dashboard/stop_bot', to: 'dashboard#stop_bot'
  get '/dashboard/bot_status', to: 'dashboard#bot_status'
  get '/dashboard/market_data', to: 'dashboard#market_data'
  get '/dashboard/diagnostics', to: 'dashboard#diagnostics'
  get '/dashboard/test_market_data', to: 'dashboard#test_market_data'
  get '/dashboard/jobs_status', to: 'dashboard#jobs_status'
  post '/dashboard/start_jobs', to: 'dashboard#start_jobs'
  
  # Paper trading routes
  get '/dashboard/paper_trading_info', to: 'dashboard#paper_trading_info'
  get '/dashboard/paper_trading_details', to: 'dashboard#paper_trading_details'
  post '/dashboard/toggle_trading_mode', to: 'dashboard#toggle_trading_mode'
  
  # Bot settings routes
  get '/bot_settings', to: 'bot_settings#index'
  patch '/bot_settings', to: 'bot_settings#update'
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  # Mount Sidekiq web UI
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end
  
  # Fallback for non-admin access
  get '/sidekiq', to: redirect('/'), constraints: lambda { |request|
    request.env['warden'].authenticate? && !request.env['warden'].user.admin?
  }

  # Mount ActionCable server
  mount ActionCable.server => '/cable'
end
