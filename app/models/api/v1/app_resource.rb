module Api
  module V1
    class AppResource < ApplicationResource
      root_key :app, :apps

      attributes :id,
        :name,
        :dokku_id,
        :created_at,
        :updated_at

      one :github_repo, resource: GithubResource

      many :deployments, resource: DeploymentResource
    end
  end
end
