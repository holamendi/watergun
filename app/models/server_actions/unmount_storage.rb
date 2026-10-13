class ServerActions::UnmountStorage
  include StorageOperation

  KEY = "apps.unmount_storage"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def storage_mount = target
  def restart = payload.fetch("restart", false)
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def host_path = payload.fetch("host_path", nil)
  def container_path = payload.fetch("container_path", nil)

  def self.default_payload(target)
    storage_mount = target
    {"dokku_app_id" => storage_mount.app.dokku_id, "host_path" => storage_mount.host_path, "container_path" => storage_mount.container_path, "restart" => false}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: StorageMount, required: %w[dokku_app_id host_path container_path])
  end

  def succeeded!
    storage_mount.update!(status: restart ? :detached : :detach_configured)
  end

  def failed!
    storage_mount.detach_failed!
  end

  def execute!(ssh)
    @ssh = ssh
    storage_mount.detaching!
    phases = storage_phase_bindings
    validate_storage_scope!(phases)
    phases.values.flatten.select { |mount| binding_present?([mount]) }.map { |mount| mount.fetch("entry_name") }.uniq.each do |name|
      ssh.execute!(Dokku::Storage::UnmountCommand.new(app: dokku_app_id, entry_name: name, container_directory: container_path))
    end
    ssh.execute!(Dokku::Ps::RestartCommand.new(app: dokku_app_id)) if restart
    if storage_phase_bindings.values.any? { |mounts| mounts.any? { |mount| mount["container_path"] == container_path } }
      raise "Storage detach was not confirmed by Dokku in deploy and run"
    end
  end
end
