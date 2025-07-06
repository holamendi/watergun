class Api::V1::AppResource < Api::ApplicationResource
  root_key :app, :apps

  attributes :id,
    :name,
    :dokku_id,
    :created_at,
    :updated_at

  one :github_repo, resource: Api::V1::GithubRepoResource
  one :deployment, resource: Api::V1::DeploymentResource
end
