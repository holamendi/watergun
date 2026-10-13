class ServerActions::SetAppBuilder
  KEY = "apps.set_builder"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def app = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def builder = payload.fetch("builder", nil)

  def self.default_payload(target)
    app = target
    {"dokku_app_id" => app.dokku_id, "builder" => app.builder}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: App, required: %w[dokku_app_id])
  end

  def succeeded!
  end

  def failed!
  end

  def execute!(ssh)
    @ssh = ssh
    set_dokku_app_builder!
  end

  def set_dokku_app_builder!
    ssh.execute!(Dokku::Builder::SetCommand.new(app: dokku_app_id, builder:))
  end
end
