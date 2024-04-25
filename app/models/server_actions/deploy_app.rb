module ServerActions
  class DeployApp < ServerAction
    alias_method :deployment, :actionable

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :repo, :string
    store_attribute :payload, :sha, :string

    validates :dokku_app_id, presence: true

    delegate :app, to: :deployment

    before_validation on: :create do
      self.dokku_app_id ||= deployment.app.dokku_id
      self.repo ||= deployment.repo
      self.sha ||= deployment.sha
    end

    def concurrency_key
      app
    end

    private

    def perform
      deployment.in_progress!

      unless sync_git_repo.success?
        deployment.failure!
        fail!("failed to sync git repo")
      end

      result = rebuild_dokku_app

      if result.success?
        deployment.success!
        app.update!(last_deployed_at: result.completed_at)
      else
        deployment.failure!
        fail!("failed to rebuild dokku app")
      end
    end

    def sync_git_repo
      Dokku::Git::Sync.call(ssh, app: dokku_app_id, repo:, sha:)
    end

    def rebuild_dokku_app
      Dokku::Ps::Rebuild.call(ssh, app: dokku_app_id)
    end
  end
end
