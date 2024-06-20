Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", :as => :rails_health_check

  # API
  namespace :api do
    namespace :v1 do
      resources :apps, only: %i[index show] do
        resources :deployments, only: %i[index show create]
      end

      resources :deployments, only: %i[index show]
      resource :ping, only: :show
    end
  end

  # Web
  root "projects#index"

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  # resources :apps do
  #   scope module: :apps do
  #     resource :command_runs, only: %i[new create show]
  #     resources :domains, only: %i[index create destroy]
  #     resource :github_repo
  #     resources :deployments, only: :create do
  #       get :logs, on: :member
  #     end
  #     resource :env_configuration, path: :environment, only: %i[edit update]
  #     resource :metrics, only: :show
  #     resources :restarts, only: :create
  #     resources :services
  #   end
  # end

  resources :projects do
    scope module: :projects do
      resources :apps do
        scope module: :apps do
          resources :domains, only: %i[index create destroy]
          resource :env_configuration, path: :environment, only: %i[edit update]
          resource :github_repo
          resources :deployments, shallow: false, only: :create do
            get :logs, on: :member
          end
          resource :metrics, only: :show
          resources :restarts, only: :create
        end
      end
      resources :services
    end
  end

  resource :org, only: :show do
    scope module: :orgs do
      resources :api_tokens
      resource :settings, only: :show
      resource :github_access_token, only: :update
    end
  end

  resources :sessions, only: %i[new create destroy]

  resources :server_actions, only: :index do
    get :logs, on: :member
  end
end
