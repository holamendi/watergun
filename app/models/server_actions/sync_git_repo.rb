module ServerActions
  class SyncGitRepo < ServerAction
    ACTION_CODE = "apps.git_sync"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :repo, :string
    store_attribute :payload, :branch, :string

    validates :dokku_app_id, :repo, :branch, presence: true

    delegate :github_repo, to: :app

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.repo ||= github_repo.repo
      self.branch ||= github_repo.branch
    end

    def concurrency_key
      app
    end

    private

    def perform
      Dokku::Git::Sync.call(ssh, app: dokku_app_id, repo:, branch:)
    end
  end
end
