Rails.application.routes.draw do
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
      resource :app_sources, path: :sources
      resource :environment_configuration, path: :environment, only: %i[edit update]
      resources :actions, only: :create
    end
  end

  resources :services do
    member do
      get :activity
      post :restart
    end
  end

  resources :sessions, only: %i[new create destroy]
end
