class ServerActions::UnmountStorage < ServerAction
  include StorageOperation

  SLUG = "apps.unmount_storage"

  actionable StorageMount

  store_attribute :payload, :restart, :boolean, default: false
  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :host_path, :string
  store_attribute :payload, :container_path, :string

  validates :dokku_app_id, presence: true
  validates :host_path, presence: true
  validates :container_path, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= storage_mount.app.dokku_id
    self.host_path ||= storage_mount.host_path
    self.container_path ||= storage_mount.container_path
  end

  def concurrency_key
    storage_mount.app
  end

  def on_failure
    storage_mount.detach_failed!
  end

  def run
    storage_mount.detaching!
    phases = storage_phase_bindings
    validate_storage_scope!(phases)
    phases.values.flatten.select { |mount| binding_present?([mount]) }.map { |mount| mount.fetch("entry_name") }.uniq.each do |name|
      execute!(Dokku::Storage::UnmountCommand.new(app: dokku_app_id, entry_name: name, container_directory: container_path))
    end
    execute!(Dokku::Ps::RestartCommand.new(app: dokku_app_id)) if restart
    if storage_phase_bindings.values.any? { |mounts| mounts.any? { |mount| mount["container_path"] == container_path } }
      raise "Storage detach was not confirmed by Dokku in deploy and run"
    end
  rescue
    storage_mount.detach_failed!
    raise
  else
    storage_mount.update!(status: restart ? :detached : :detach_configured)
  end
end
