class ServerActions::UpdateEnv
  KEY = "apps.update_env"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def app = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def set = payload.fetch("set", {})
  def unset = payload.fetch("unset", [])
  def restart = payload.fetch("restart", false)

  def self.default_payload(target)
    app = target
    {"dokku_app_id" => app.dokku_id, "set" => {}, "unset" => [], "restart" => false}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: App, required: %w[dokku_app_id])
  end

  def succeeded!
    schedule_pull_env!
    schedule_restart! if restart
  end

  def failed!
  end

  def execute!(ssh)
    @ssh = ssh
    set_dokku_app_config! if set.present?
    unset_dokku_app_config! if unset.present?
  end

  def set_dokku_app_config!
    ssh.execute!(Dokku::Config::SetCommand.new(app: dokku_app_id, env: set))
  end

  def unset_dokku_app_config!
    ssh.execute!(Dokku::Config::UnsetCommand.new(app: dokku_app_id, variable_names: unset))
  end

  def schedule_pull_env!
    ServerAction::Enqueue.call(action: ServerActions::PullEnv, target: app)
  end

  def schedule_restart!
    ServerAction::Enqueue.call(action: ServerActions::RestartApp, target: app)
  end
end
