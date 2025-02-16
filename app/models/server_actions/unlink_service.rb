class ServerActions::UnlinkService < ServerAction
  SLUG = "services.unlink"

  actionable ServiceLink

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :dokku_service_id, :string
  store_attribute :payload, :service_type, :string

  validates :dokku_app_id, :dokku_service_id, :service_type, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
    self.dokku_service_id ||= service.dokku_id
    self.service_type ||= service.service_type
  end

  delegate :app, :service, to: :service_link

  def concurrency_key
    service
  end

  private

  def run
    service_link.deleting!
    unlink_dokku_service!
    schedule_pull_env!
  rescue Ssh::CommandExecutionError
    service_link.error!
    raise
  else
    service_link.destroy!
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
    ServerActions::PullEnv.run_later!(server, app)
  end
end
