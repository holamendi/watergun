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
    end
  end

  # Web
  root "apps#index"

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  resources :sessions, only: %i[new create destroy]

  resources :server_actions, only: :index do
    get :logs, on: :member
  end

  resources :apps do
    scope module: :apps do
      resource :command_runs, only: %i[new create show]
      resource :github_repo
      resources :deployments, only: :create do
        get :logs, on: :member
      end
      resource :env_configuration, path: :environment, only: %i[edit update]
      resource :metrics, only: :show
      resources :services
    end
  end

  resource :org, only: :show do
    scope module: :orgs do
      resource :settings, only: :show
      resource :github_access_token, only: :update
    end
  end
end
