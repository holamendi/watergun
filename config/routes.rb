Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up", to: "rails/health#show", as: :rails_health_check

  root "root#index"

  get "login", to: "sessions#new", as: :login
  delete "logout", to: "sessions#destroy", as: :logout

  resource :session, only: %i[new create destroy]

  resource :first_run, only: %i[edit update]
  get "first-run/:signed_id", to: "first_runs#edit"

  resources :hooks

  concern :log_streamable do
    resources :log_streams, path: :logs, only: %i[index create show update destroy]
  end

  concern :metrizable do
    resource :metrics, only: :show do
      get :stats
      get :cpu_chart
      get :memory_chart
    end
  end

  resources :projects do
    scope module: :projects do
      resources :apps do
        scope module: :apps do
          resource :builder, only: %i[update]
          resources :deployments, shallow: false, only: :create do
            get :logs, on: :member
          end

          resources :domains, only: %i[index create destroy] do
            patch :make_default, on: :member
          end

          resources :env_variables, path: :env
          resource :github_repo
          resources :restarts, only: :create

          concerns :log_streamable
          concerns :metrizable
        end
      end

      resources :services do
        scope module: :services do
          resources :restarts, only: :create
          concerns :log_streamable
          concerns :metrizable
        end
      end
    end
  end

  resources :server_actions, only: :index do
    get :logs, on: :member
  end

  # Account settings
  resource :account, controller: "accounts/settings" do
    scope module: :accounts do
      resource :profile, only: :update
      resources :api_tokens, only: %i[index create destroy]
      resource :github_integrations, only: %i[create destroy]
    end
  end

  # Github events
  namespace :github do
    resource :installation, only: %i[create destroy] do
      get :callback, on: :collection
    end

    resource :registration, only: [] do
      get :callback, on: :collection
    end

    post ":token/events", to: "events#create", as: :events
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
