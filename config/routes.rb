Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", :as => :rails_health_check

  get "login" => "sessions#new", :as => :login
  delete "logout" => "sessions#destroy", :as => :logout

  root "apps#index"

  resources :actions, only: [] do
    get :logs, on: :member
  end

  resources :apps do
    scope module: :apps do
      resource :deploy_source
      resources :deployments, only: :create
      resource :environment_configuration, path: :environment, only: %i[edit update]
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

  # resources :services do
  #   scope module: :services do
  #     resource :metrics, only: :show
  #     resources :service_links, only: %i[index new create destroy], path: :links
  #   end
  # end

  resources :sessions, only: %i[new create destroy]
end
