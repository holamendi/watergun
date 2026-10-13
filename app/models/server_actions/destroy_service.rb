class ServerActions::DestroyService
  KEY = "services.destroy"

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
    service.destroy!
  end

  def failed!
    service.error! unless service.destroyed?
  end

  def execute!(ssh)
    @ssh = ssh
    service.deleting!
    destroy_dokku_service!
  end

  def destroy_dokku_service!
    ssh.execute!(Dokku::Services::DestroyCommand.new(plugin: service_type, name: dokku_service_id))
  end
end
