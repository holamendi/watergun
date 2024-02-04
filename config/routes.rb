Rails.application.routes.draw do
  resources :git_credentials
  resources :apps do
    member do
      get :activity
      get :metrics
      post :restart
      post :deploy
    end
    collection do
      get :select_git_repo
    end
  end
  resources :services do
    member do
      get :activity
      post :restart
    end
  end
  resources :sessions, only: %i[new create destroy]
  resources :server_events, path: "events", only: [] do
    member do
      get :logs
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  # Defines the root path route ("/")
  root "apps#index"
end
