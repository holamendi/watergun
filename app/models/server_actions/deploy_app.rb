module ServerActions
  class DeployApp < ServerAction
    ACTION_CODE = "apps.deploy"

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
      authenticate_github_account

      unless sync_git_repo.success?
        deployment.failure!
        fail!("failed to sync git repo")
      end

      result = rebuild_dokku_app

      if result.success?
        deployment.success!
        update_app_urls!
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

    def update_app_urls!
      urls = Dokku::Urls.call(ssh, app: dokku_app_id).parse
      app.update!(urls:) if urls.present?
    end

    def authenticate_github_account
      return unless github_access_token

      Dokku::Git::Auth.call(ssh, access_token: github_access_token.token)
    end

    def github_access_token
      @github_access_token ||= deployment.org.github_access_token
    end
  end
end
