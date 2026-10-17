class Api::V1::AppResource < Api::ApplicationResource
  root_key :app, :apps

  attributes :id,
    :name,
    :dokku_id,
    :created_at,
    :updated_at

  attributes :status, :project_id, :server_id
  attribute :env_names do |app|
    app.env_variables.kept.where(account_id: app.account_id).order(:name).pluck(:name).uniq
  end
  attribute :url do |app|
    app.domains.kept.active.where(account_id: app.account_id, is_default: true).first&.url
  end

  one :github_repo, resource: Api::V1::GithubRepoResource, source: ->(_) { Github::Repo.find_by(app_id: id, account_id: account_id) }
  one :deployment, resource: Api::V1::DeploymentResource, source: ->(_) { deployments.where(account_id: account_id).success.recent.first }
end
