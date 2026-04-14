Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: [:new, :create]
  root "dashboard#index"

  resources :legislations, only: [:index, :show]
  get "search", to: "search#index"

  namespace :admin do
    resources :ingestion_logs, only: [:index]
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", as: :rails_health_check
end
