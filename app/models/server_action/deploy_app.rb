class ServerAction::DeployApp < ServerAction
  SLUG = "apps.deploy"

  actionable Deployment

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :repo, :string
  store_attribute :payload, :sha, :string

  validates :dokku_app_id, presence: true

  delegate :app, :account, to: :deployment

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
    self.repo ||= deployment.repo
    self.sha ||= deployment.sha
  end

  def concurrency_key
    app
  end

  private

  def run
    deployment.deploying!
    app.deploying!
    authenticate_github_account!
    sync_git_repo!
    rebuild_dokku_app!
    schedule_enable_ssl!
  rescue Ssh::CommandExecutionError
    deployment.error!
    raise
  else
    deployment.success!
  ensure
    app.active!
    notify_user
    schedule_pull_env!
  end

  def sync_git_repo!
    Dokku::Git::Sync.call!(ssh, app: dokku_app_id, repo:, sha:)
  end

  def rebuild_dokku_app!
    Dokku::Ps::Rebuild.call!(ssh, app: dokku_app_id)
  end

  def authenticate_github_account!
    return unless github_access_token

    Dokku::Git::Auth.call!(ssh, access_token: github_access_token.token)
  end

  def github_access_token
    account.github_access_token
  end

  def schedule_enable_ssl!
    return unless app.domains.ssl_disabled.any?
    return unless app.all_domains_resolve_to_server?

    ServerAction::EnableSsl.run_later!(app)
  end

  def schedule_pull_env!
    ServerAction::PullEnv.run_later!(app)
  end

  def notify_user
    message, type = if deployment.success?
      ["#{app.name}: deployment finished", :success]
    else
      ["#{app.name}: deployment failed", :notice]
    end

    user.notify_later(message, type:)
  end
end
