module DeploySources
  class Github < DeploySource
    store_attribute :data, :repository, :string
    store_attribute :data, :branch, :string, default: "main"

    validates :repository, :branch, presence: true

    after_create_commit -> do
      app.enqueue_action!(
        :set_deploy_source,
        dokku_id:,
        source_type:,
        github_repository: repository,
        github_branch: branch
      )
    end
  end
end
