require 'sidekiq/web'

Rails.application.routes.draw do
  # Position management routes
  resources :positions, only: [:index, :show, :create] do
    member do
      post :close_manually
    end
  end
  get "home/index"
  devise_for :users
  
  # Dashboard routes
  get '/dashboard', to: 'dashboard#index'
  
  # Bot state management routes
  post '/dashboard/bot/start', to: 'dashboard#start_bot'
  post '/dashboard/bot/stop', to: 'dashboard#stop_bot'
  get '/dashboard/bot/status', to: 'dashboard#bot_status'
  get '/dashboard/market_data/:symbol', to: 'dashboard#market_data'
  
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
