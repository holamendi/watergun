class ServerActions::RestartApp
  KEY = "apps.restart"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def app = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)

  def self.default_payload(target)
    app = target
    {"dokku_app_id" => app.dokku_id}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: App, required: %w[dokku_app_id])
  end

  def succeeded!
    @restart_completed = true
    app.active!
    notify_user
  end

  def failed!
    return if app.destroyed? || (@restart_completed && app.reload.active?)

    app.error!
  end

  def execute!(ssh)
    @ssh = ssh
    app.restarting!
    restart_dokku_app!
  end

  def restart_dokku_app!
    ssh.execute!(Dokku::Ps::RestartCommand.new(app: dokku_app_id))
  end

  def notify_user
    return unless user

    Toast.append_to_user(user, "#{app.name}: restart finished")
  end
end
