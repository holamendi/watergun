class ServerActions::MountStorage < ServerAction
  include StorageOperation

  SLUG = "apps.mount_storage"

  actionable StorageMount

  store_attribute :payload, :restart, :boolean, default: false
  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :host_path, :string
  store_attribute :payload, :container_path, :string
  store_attribute :payload, :chown, :string

  validates :dokku_app_id, presence: true
  validates :host_path, presence: true
  validates :container_path, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= storage_mount.app.dokku_id
    self.host_path ||= storage_mount.host_path
    self.container_path ||= storage_mount.container_path
    self.chown ||= storage_mount.chown
  end

  def concurrency_key
    storage_mount.app
  end

  def on_failure
    storage_mount.error!
  end

  def run
    phases = storage_phase_bindings
    if phases.values.any? { |mounts| mounts.any? { |mount| mount["container_path"] == container_path && mount["host_path"] != host_path } }
      raise "Container path is already mounted from another directory"
    end
    missing = phases.select { |phase, mounts| !binding_present?(mounts) }.keys
    ensure_directory! if missing.any?
    missing.each { |phase| mount_storage!(phase) }
    execute!(Dokku::Ps::RestartCommand.new(app: dokku_app_id)) if restart
    unless storage_phase_bindings.values.all? { |mounts| binding_present?(mounts) }
      raise "Storage mount was not confirmed by Dokku in deploy and run"
    end
  rescue
    storage_mount.error!
    raise
  else
    storage_mount.update!(status: restart ? :active : :configured)
  end

  private

  def ensure_directory!
    if host_path.match?(%r{\A/var/lib/dokku/data/storage/watergun-[a-f0-9]{32}\z})
      execute!(Dokku::Storage::EnsureDirectory.new(directory: File.basename(host_path), chown: chown))
    else
      # Preserve legacy paths and data; never create a different directory on retry.
      execute!("test -d #{Shellwords.escape(host_path)}")
    end
  end

  def mount_storage!(phase)
    execute!(Dokku::Storage::Mount.new(app: dokku_app_id, host_directory: host_path, container_directory: container_path, phase: phase))
  end
end
