class Api::V1::AppResource < Api::ApplicationResource
  root_key :app, :apps

  attributes :id,
    :name,
    :dokku_id,
    :created_at,
    :updated_at

  one :github_repo, resource: Api::V1::GithubRepoResource, source: ->(_) { Github::Repo.find_by(app_id: id, account_id: account_id) }
  one :deployment, resource: Api::V1::DeploymentResource, source: ->(_) { deployments.where(account_id: account_id).success.recent.first }
end
