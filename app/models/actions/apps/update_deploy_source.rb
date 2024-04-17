module Actions
  module Apps
    class UpdateDeploySource < Action
      SOURCE_TYPES = %w[github].freeze

      store_attribute :payload, :dokku_app_id, :string
      store_attribute :payload, :source_type, :string
      store_attribute :payload, :github_repo, :string
      store_attribute :payload, :github_branch, :string

      validates :dokku_id, presence: true
      validates :source_type, inclusion: {in: SOURCE_TYPES}

      with_options if: -> { github_source? } do
        validates :github_repository, presence: true
        validates :github_branch, presence: true
      end

      def github_source?
        source_type == "github"
      end

      def perform
        update_deploy_source
      end

      private

      def update_deploy_source
        ssh.execute(Dokku::Git.auth(dokku_id, git_source))
      end
    end
  end
end
