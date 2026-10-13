class ServerActions::RestartService
  KEY = "services.restart"

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
    {"service_type" => service.service_type, "dokku_service_id" => service.dokku_id}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: Service, required: %w[dokku_service_id])
  end

  def succeeded!
    @restart_completed = true
    service.active!
    notify_user
  end

  def failed!
    return if service.destroyed? || (@restart_completed && service.reload.active?)

    service.error!
  end

  def execute!(ssh)
    @ssh = ssh
    service.restarting!
    restart_dokku_service!
  end

  def restart_dokku_service!
    ssh.execute!(Dokku::Services::RestartCommand.new(plugin: service_type, service: dokku_service_id))
  end

  def notify_user
    return unless user

    Toast.append_to_user(user, "#{service.name}: restart finished")
  end
end
