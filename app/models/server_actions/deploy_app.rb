class ServerActions::DeployApp < ServerAction
  include ActionView::RecordIdentifier

  SLUG = "apps.deploy"

  actionable Deployment

  self.persist_logs_interval = 1.second

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :repo, :string
  store_attribute :payload, :sha, :string

  validates :dokku_app_id, presence: true

  delegate :app, :account, to: :deployment, allow_nil: true

  def on_logs_persisted(commands:)
    current_text = commands.map(&:text_output).join
    new_text = current_text[(@last_broadcast_length || 0)..]
    @last_broadcast_length = current_text.length

    return if new_text.blank?

    broadcast_log_chunk(new_text)
  end

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
    self.repo ||= deployment.repo
    self.sha ||= deployment.sha
  end

  def concurrency_key = app

  private

  def run
    deployment.deploying!
    app.deploying!
    authenticate_github_account!
    sync_git_repo!
    rebuild_dokku_app!
    schedule_enable_ssl!
  rescue
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
    execute!(Dokku::Git::SyncCommand.new(app: dokku_app_id, repo:, sha:))
  end

  def rebuild_dokku_app!
    execute!(Dokku::Ps::RebuildCommand.new(app: dokku_app_id))
  end

  def authenticate_github_account!
    execute!(Dokku::Git::AuthCommand.new(access_token: github_access_token))
  end

  def github_access_token
    account.github_installation.access_token.token
  end

  def schedule_enable_ssl!
    return unless app.domains.ssl_disabled.any?
    return unless app.all_domains_resolve_to_server?

    ServerActions::EnableSsl.run_later!(app.server, app)
  end

  def schedule_pull_env!
    ServerActions::PullEnv.run_later!(app.server, app)
  end

  def notify_user
    return unless user

    message, type = if deployment.success?
      ["#{app.name}: deployment finished", :success]
    else
      ["#{app.name}: deployment failed", :notice]
    end

    Toast.append_to_user(user, message, type:)
  end

  def broadcast_log_chunk(content)
    Turbo::StreamsChannel.broadcast_append_to(
      deployment,
      target: dom_id(deployment, :logs),
      partial: "projects/apps/deployments/log_chunk",
      locals: {content:}
    )
  end
end
