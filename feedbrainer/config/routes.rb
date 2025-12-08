Rails.application.routes.draw do
  # Authentication
  get "/login", to: "sessions#new", as: :login
  delete "/logout", to: "sessions#destroy", as: :logout


  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Comprehensive health check endpoints
  get "health" => "health#show"
  get "health/detailed" => "health#detailed"
  get "health/pipeline" => "health#pipeline"
  get "health/test_did" => "health#test_did"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Bluesky OAuth routes
  get "/auth/bluesky/start", to: "bluesky_auth#start", as: :bluesky_auth_start
  get "/auth/atproto/callback", to: "bluesky_auth#callback"
  post "/auth/atproto/callback", to: "bluesky_auth#callback"
  get "/auth/failure", to: "bluesky_auth#failure"
  get "/oauth/client-metadata.json", to: "bluesky_auth#client_metadata"

  # API routes
  namespace :api do
    resources :sources, only: [:index]
  end

  # Defines the root path route ("/")
  root "home#index"
  get "/network", to: "home#network", as: :network
  
  # Explicit routes for JSON and RSS formats
  get "/index", to: "home#index", as: :home_index
  
  # Mount Letter Opener Web in development
  resources :chats do
    resources :messages, only: [:create]
  end
end
