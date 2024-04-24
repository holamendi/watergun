module ServerActions
  class DeployDokkuApp < ServerAction
    alias_method :deployment, :actionable

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :repo, :string
    store_attribute :payload, :branch, :string
    store_attribute :payload, :rev, :string

    validates :dokku_app_id, presence: true

    delegate :app, to: :deployment

    before_validation on: :create do
      self.dokku_app_id ||= deployment.app.dokku_id
      self.repo ||= deployment.repo
      self.branch ||= deployment.branch
      self.rev ||= deployment.rev
    end

    def concurrency_key
      app
    end

    private

    def perform
      return unless sync_git_repo.success?

      rebuild_dokku_app.then do |command|
        app.update_columns(last_deployed_at: command.result.completed_at) if command.success?
      end
    end

    def sync_git_repo
      Dokku::Git::Sync.call(ssh, app: dokku_app_id, repo:, branch:)
    end

    def rebuild_dokku_app
      Dokku::Ps::Rebuild.call(ssh, app: dokku_app_id)
    end
  end
end
