Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: [:new, :create]
  root "dashboard#index"

  resources :legislations, only: [:index, :show]
  get "search", to: "search#index"

  resources :watchlists, only: [:index, :show, :destroy] do
    resources :watchlist_items, only: [:destroy], module: :watchlists
  end
  post "legislations/:id/watch", to: "watchlists#watch", as: :watch_legislation
  delete "legislations/:id/unwatch", to: "watchlists#unwatch", as: :unwatch_legislation

  resource :alert_preferences, only: [:edit, :update]

  namespace :api do
    namespace :v1 do
      resources :legislations, only: [:index, :show]
      resources :jurisdictions, only: [:index, :show]
      get "search", to: "search#index"
    end
  end

  namespace :admin do
    resources :ingestion_logs, only: [:index]
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "eli/*path", to: "eli#resolve", as: :eli_resolve

  get "up" => "rails/health#show", as: :rails_health_check
end
