class ServerActions::CreateService < ServerAction
  SLUG = "services.create"

  actionable Service

  store_attribute :payload, :dokku_service_id, :string
  store_attribute :payload, :service_type, :string

  validates :dokku_service_id, presence: true
  validates :service_type, presence: true

  before_validation on: :create do
    self.dokku_service_id ||= service.dokku_id
    self.service_type ||= service.service_type
  end

  private

  def run
    install_dokku_plugin! unless dokku_plugin_installed?

    create_dokku_service!
    service.data = dokku_service_info
    link_to_project_apps!
  rescue Ssh::CommandExecutionError
    service.error!
    raise
  else
    service.active!
  end

  def create_dokku_service!
    ssh.execute!(Dokku::Services::CreateCommand.new(plugin: service_type, name: dokku_service_id))
  end

  def dokku_service_info
    ssh.execute!(Dokku::Services::InfoCommand.new(plugin: service_type, service: dokku_service_id)).parsed_output
  end

  def link_to_project_apps!
    service.project.apps.kept.each { |app| ServiceLink::CreateServiceLink.new(service:, app:).create }
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
