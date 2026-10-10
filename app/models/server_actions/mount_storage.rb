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
    validate_storage_scope!(phases)
    if phases.values.any? { |mounts| mounts.any? { |mount| mount["container_path"] == container_path && mount["host_path"] != host_path } }
      raise "Container path is already mounted from another directory"
    end
    missing = phases.select { |phase, mounts| !binding_present?(mounts) }.keys
    if missing.any?
      execute!("test -d #{Shellwords.escape(host_path)}") unless managed_host_path?
      name = storage_entry_name(phases)
      execute!(Dokku::Storage::Mount.new(app: dokku_app_id, entry_name: name, container_directory: container_path))
    end
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

  def managed_host_path?
    host_path.match?(%r{\A/var/lib/dokku/data/storage/watergun-[a-f0-9]{32}\z})
  end

  def storage_entry_name(phases)
    binding = phases.values.flatten.find { |mount| binding_present?([mount]) }
    return binding.fetch("entry_name") if binding

    entries = execute!(Dokku::Storage::ListEntriesCommand.new).parsed_output
    entry = entries.find { |item| item["host_path"] == host_path }
    return entry.fetch("name") if entry

    name = managed_host_path? ? File.basename(host_path) : "watergun-#{Digest::SHA256.hexdigest(host_path).first(32)}"
    raise "Storage entry name is already registered for another directory" if entries.any? { |item| item["name"] == name }

    if managed_host_path?
      execute!(Dokku::Storage::CreateEntry.new(name: name, chown: chown))
    else
      # Register the exact retained path; never create a replacement or chown it.
      execute!(Dokku::Storage::CreateEntry.new(name: name, path: host_path))
    end
    name
  end
end
