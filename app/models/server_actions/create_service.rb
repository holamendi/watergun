class ServerActions::CreateService
  KEY = "services.create"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def service = target
  def dokku_service_id = payload.fetch("dokku_service_id", nil)
  def service_type = payload.fetch("service_type", nil)

  def self.default_payload(target)
    service = target
    {"dokku_service_id" => service.dokku_id, "service_type" => service.service_type}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: Service, required: %w[dokku_service_id service_type])
  end

  def succeeded!
    service.data = dokku_service_info
    create_service_links!
    @creation_completed = true
    service.active!
  end

  def failed!
    return if service.destroyed? || (@creation_completed && service.reload.active?)

    service.error!
  end

  def execute!(ssh)
    @ssh = ssh
    install_dokku_plugin! unless dokku_plugin_installed?

    create_dokku_service!
  end

  def create_dokku_service!
    ssh.execute!(Dokku::Services::CreateCommand.new(plugin: service_type, name: dokku_service_id))
  end

  def dokku_service_info
    ssh.execute!(Dokku::Services::InfoCommand.new(plugin: service_type, service: dokku_service_id)).parsed_output
  end

  def create_service_links!
    service.project.apps.kept.each { |app| ServiceLink::CreateServiceLink.new(service:, app:).save! }
  end

  def dokku_plugins
    @_dokku_plugins ||= ssh.execute!(Dokku::Plugin::ListCommand.new).parsed_output
  end

  def dokku_plugin_installed?
    dokku_plugins.find { |plugin| plugin.name == service_type }
  end

  def install_dokku_plugin!
    ssh.execute!(Dokku::Plugin::InstallCommand.new(plugin: service_type))
  end
end
