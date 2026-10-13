class ServerActions::DeployApp
  include ActionView::RecordIdentifier

  KEY = "apps.deploy"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def deployment = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def repo = payload.fetch("repo", nil)
  def sha = payload.fetch("sha", nil)

  def self.default_payload(target)
    deployment = target
    app = target.app
    {"dokku_app_id" => app.dokku_id, "repo" => deployment.repo, "sha" => deployment.sha}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: Deployment, required: %w[dokku_app_id])
  end

  def succeeded!
    schedule_enable_ssl!
    deployment.success!
    app.active!
    broadcast_deployment_update
    notify_user
    schedule_pull_env!
  end

  LOG_INTERVAL = 1.second

  delegate :app, to: :deployment, allow_nil: true

  def on_logs_persisted(commands:)
    current_text = commands.map(&:text_output).join
    new_text = current_text[(@last_broadcast_length || 0)..]
    return if new_text.blank?

    broadcast_log_chunk(new_text)
    @last_broadcast_length = current_text.length
  end

  def failed!
    return if deployment.persisted? && deployment.reload.success?

    begin
      deployment.error! unless deployment.destroyed?
    ensure
      app.error! unless app.destroyed?
    end
    broadcast_deployment_update
    notify_user
  end

  def execute!(ssh)
    @ssh = ssh
    deployment.deploying!
    app.deploying!
    broadcast_deployment_update
    authenticate_github_account!
    sync_git_repo!
    rebuild_dokku_app!
  end

  def sync_git_repo!
    ssh.execute!(Dokku::Git::SyncCommand.new(app: dokku_app_id, repo:, sha:))
  end

  def rebuild_dokku_app!
    ssh.execute!(Dokku::Ps::RebuildCommand.new(app: dokku_app_id))
  end

  def authenticate_github_account!
    ssh.execute!(Dokku::Git::AuthCommand.new(access_token: github_access_token))
  end

  def github_access_token
    account.github_installation.access_token.token
  end

  def schedule_enable_ssl!
    return unless app.domains.ssl_disabled.any?
    return unless app.all_domains_resolve_to_server?

    ServerAction::Enqueue.call(action: ServerActions::EnableSsl, target: app)
  end

  def schedule_pull_env!
    ServerAction::Enqueue.call(action: ServerActions::PullEnv, target: app)
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

  def broadcast_deployment_update
    # Update deployment row on index page
    Turbo::StreamsChannel.broadcast_replace_to(
      [app, :deployments],
      target: dom_id(deployment),
      partial: "projects/apps/deployments/deployment",
      locals: {deployment:}
    )

    # Update show page info card
    Turbo::StreamsChannel.broadcast_replace_to(
      deployment,
      target: dom_id(deployment, :info),
      partial: "projects/apps/deployments/deployment_info",
      locals: {deployment:}
    )
  end
end
