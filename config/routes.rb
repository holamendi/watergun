Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", :as => :rails_health_check

  # API
  namespace :api do
    namespace :v1 do
      resources :apps, only: %i[index show] do
        resources :deployments, only: %i[index show create]
      end
    end
  end

  # Web
  root "apps#index"

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  scope module: :web do
    resources :sessions, only: %i[new create destroy]

    resources :server_actions, only: :index do
      get :logs, on: :member
    end

    resources :apps do
      scope module: :apps do
        resource :github_repo
        resources :deployments, only: :create
        resource :env_configuration, path: :enironment, only: %i[edit update]
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
end
