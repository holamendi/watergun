class ServerActions::LinkService < ServerAction
  SLUG = "services.link"

  actionable ServiceLink

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :dokku_service_id, :string
  store_attribute :payload, :service_type, :string
  store_attribute :payload, :env_name, :string

  validates :dokku_app_id, presence: true
  validates :dokku_service_id, presence: true
  validates :service_type, presence: true
  validates :env_name, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
    self.dokku_service_id ||= service.dokku_id
    self.service_type ||= service.service_type
    self.env_name ||= env_variable.name
  end

  delegate :app, :service, :env_variable, to: :service_link

  def concurrency_key
    service
  end

  def run
    link_dokku_service!
    schedule_pull_env!
  rescue Ssh::CommandExecutionError
    service_link.error!
    raise
  else
    service_link.active!
  end

  private

  def link_dokku_service!
    ssh.execute!(Dokku::Services::LinkCommand.new(plugin: service_type, service: dokku_service_id, app: dokku_app_id, env_name:))
  end

  def schedule_pull_env!
    ServerActions::PullEnv.run_later!(server, app)
  end
end
