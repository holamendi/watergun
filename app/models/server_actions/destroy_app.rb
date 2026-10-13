class ServerActions::DestroyApp
  KEY = "apps.destroy"

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
    app.destroy!
  end

  def failed!
    app.error! unless app.destroyed?
  end

  def execute!(ssh)
    @ssh = ssh
    app.deleting!
    destroy_dokku_app!
  end

  def destroy_dokku_app!
    ssh.execute!(Dokku::Apps::DestroyCommand.new(app: dokku_app_id))
  end
end
