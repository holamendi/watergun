module Api
  module V1
    class DeploymentResource < ApplicationResource
      root_key :deployment, :deployments

      attributes :id,
        :app_id,
        :repo,
        :sha,
        :status,
        :source,
        :queued_at,
        :started_at,
        :finished_at

      def queued_at(deployment)
        deployment.created_at
      end
    end
  end
end
