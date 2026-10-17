Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up", to: "rails/health#show", as: :rails_health_check

  root "projects#index"

  get "login", to: "sessions#new", as: :login
  delete "logout", to: "sessions#destroy", as: :logout

  resource :session, only: %i[new create destroy]

  resource :first_run, only: %i[edit update]
  get "first-run/:signed_id", to: "first_runs#edit", as: :pretty_first_run

  resources :hooks

  concern :log_streamable do
    resources :log_streams, path: :logs, only: %i[index create show update destroy]
  end

  concern :metrics do
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
          resources :deployments, only: %i[index create show] do
            get :logs, on: :member
          end

          resources :domains, only: %i[index create destroy] do
            patch :make_default, on: :member
          end

          resources :env_variables, path: :env
          resources :storage_mounts, path: :storage, only: %i[index create update destroy]
          resource :github_repo, only: :update
          resources :restarts, only: :create

          resource :settings, only: :show

          concerns :log_streamable
          concerns :metrics
        end
      end

      resources :services, except: :index do
        scope module: :services do
          resources :restarts, only: :create
          concerns :log_streamable
          concerns :metrics
        end
      end

      resources :service_links, only: %i[create destroy]
    end
  end

  resources :servers, only: [] do
    post :select, on: :member
  end

  resources :server_actions, only: [:index, :show]

  resource :account, controller: "accounts/settings" do
    scope module: :accounts do
      resource :profile, only: :update
      resources :api_tokens, only: %i[index show create destroy] do
        post :rotate, on: :member
        post :claim, on: :collection
      end
    end
  end

  namespace :github do
    get "app_registrations/callback", to: "app_registrations#callback", as: :app_registrations_callback
    resources :installations, only: [:destroy] do
      get :callback, on: :collection
    end

    resources :events, only: %i[create]
  end

  namespace :api do
    namespace :v1 do
      resources :operations, only: :show
      resources :projects, only: :index do
        resources :apps, only: %i[index create]
      end
      resources :apps, only: %i[index show destroy] do
        put :env, on: :member, to: "env#update"
        post :restart, path: :restarts, on: :member
        resources :deployments, only: %i[index show create]
        resource :ping, only: :show
      end
    end

    namespace :internal do
      resources :setups, only: :create
    end
  end
end
