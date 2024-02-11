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
    collection do
      get :select_git_repo
    end

    scope module: :apps do
      resources :app_sources, path: :sources
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
