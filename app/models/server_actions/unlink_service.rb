class ServerActions::UnlinkService
  KEY = "services.unlink"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def service_link = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def dokku_service_id = payload.fetch("dokku_service_id", nil)
  def service_type = payload.fetch("service_type", nil)

  def self.default_payload(target)
    app = target.app
    service = target.service
    target.env_variable
    {"dokku_app_id" => app.dokku_id, "dokku_service_id" => service.dokku_id, "service_type" => service.service_type}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: ServiceLink, required: %w[dokku_app_id dokku_service_id service_type])
    [app, service].each { |child| ServerAction::TargetValidation.ownership!(@run, child) }
  end

  def succeeded!
    schedule_pull_env!
    service_link.destroy!
  end

  delegate :app, :service, to: :service_link

  def failed!
    service_link.error! unless service_link.destroyed?
  end

  def execute!(ssh)
    @ssh = ssh
    service_link.deleting!
    unlink_dokku_service!
  end

  def unlink_dokku_service!
    ssh.execute!(
      Dokku::Services::UnlinkCommand.new(
        plugin: service_type,
        service: dokku_service_id,
        app: dokku_app_id
      )
    )
  end

  def schedule_pull_env!
    ServerAction::Enqueue.call(action: ServerActions::PullEnv, target: app)
  end
end
