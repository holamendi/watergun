class ServerActions::RestartService < ServerAction
  SLUG = "services.restart"

  actionable Service

  store_attribute :payload, :dokku_service_id, :string
  store_attribute :payload, :service_type, :string

  validates :dokku_service_id, presence: true

  before_validation on: :create do
    self.service_type ||= service.service_type
    self.dokku_service_id ||= service.dokku_id
  end

  private

  def run
    service.restarting!
    restart_dokku_service!
  rescue Ssh::CommandExecutionError
    service.error!
    raise
  else
    service.active!
    notify_user
  end

  def restart_dokku_service!
    execute!(Dokku::Services::RestartCommand.new(plugin: service_type, service: dokku_service_id))
  end

  def notify_user
    return unless user

    Toast.append_to_user(user, "#{service.name}: restart finished")
  end
end
