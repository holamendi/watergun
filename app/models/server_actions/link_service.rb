class ServerActions::LinkService
  KEY = "services.link"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def service_link = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def dokku_service_id = payload.fetch("dokku_service_id", nil)
  def service_type = payload.fetch("service_type", nil)
  def env_name = payload.fetch("env_name", nil)

  def self.default_payload(target)
    app = target.app
    service = target.service
    env_variable = target.env_variable
    {"dokku_app_id" => app.dokku_id, "dokku_service_id" => service.dokku_id, "service_type" => service.service_type, "env_name" => env_variable.name}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: ServiceLink, required: %w[dokku_app_id dokku_service_id service_type env_name])
    [app, service, env_variable].each { |child| ServerAction::TargetValidation.ownership!(@run, child) }
  end

  def succeeded!
    schedule_pull_env!
    @link_completed = true
    service_link.active!
  end

  delegate :app, :service, :env_variable, to: :service_link

  def failed!
    return if @link_completed && service_link.reload.active?

    service_link.error!
  end

  def execute!(ssh)
    @ssh = ssh
    link_dokku_service!
  end

  def link_dokku_service!
    ssh.execute!(Dokku::Services::LinkCommand.new(plugin: service_type, service: dokku_service_id, app: dokku_app_id, env_name:))
  end

  def schedule_pull_env!
    ServerAction::Enqueue.call(action: "apps.pull_env", target: app)
  end
end
