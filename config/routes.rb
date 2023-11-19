Rails.application.routes.draw do
  resources :apps do
    member do
      get :logs
      get :metrics
    end
  end
  resources :memberships
  resources :orgs
  resources :servers
  resources :sessions, only: %i[new create destroy]
  resources :users
  resources :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Defines the root path route ("/")
  root "apps#index"
end
