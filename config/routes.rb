Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", :as => :rails_health_check

  root "projects#index"

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  resources :sessions, only: %i[new create destroy]

  resources :projects do
    scope module: :projects do
      resources :apps do
        scope module: :apps do
          resources :domains, only: %i[index create destroy] do
            patch :make_default, on: :member
          end
          resources :env_variables, path: :env
          resource :env_configuration, path: :environment, only: %i[edit update]
          resource :github_repo
          resources :deployments, shallow: false, only: :create do
            get :logs, on: :member
          end
          resources :logs, only: :index do
            get :fetch, on: :collection
          end
          resource :metrics, only: :show do
            get :stats
            get :cpu_chart
            get :memory_chart
          end
          resources :restarts, only: :create
        end
      end
      resources :services
    end
  end

  resources :server_actions, only: :index do
    get :logs, on: :member
  end

  # Account settings
  resource :account do
    resources :api_tokens, only: %i[index create destroy]
    resources :github_access_tokens, only: %i[new create destroy]
  end

  # API
  namespace :api do
    namespace :v1 do
      resources :apps, only: %i[index show] do
        resources :deployments, only: %i[index show]
        resource :ping, only: :show
      end
    end
  end
end
