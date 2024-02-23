Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", :as => :rails_health_check

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  root "apps#index"

  resources :git_credentials

  resources :apps do
    member do
      post :deploy
      post :disable_ssl
      post :enable_ssl
      post :restart
    end

    scope module: :apps do
      resources :actions, only: :create
      resource :deploy_source
      resource :environment_configuration, path: :environment, only: %i[edit update]
      resource :metrics, only: :show
    end
  end

  resources :services do
    scope module: :services do
      resource :metrics, only: :show
    end
  end

  resources :sessions, only: %i[new create destroy]
end
