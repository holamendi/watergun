class ServerActions::MountStorage
  include StorageOperation

  KEY = "apps.mount_storage"

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
  def chown = payload.fetch("chown", nil)

  def self.default_payload(target)
    storage_mount = target
    {"dokku_app_id" => storage_mount.app.dokku_id, "host_path" => storage_mount.host_path, "container_path" => storage_mount.container_path, "chown" => storage_mount.chown, "restart" => false}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: StorageMount, required: %w[dokku_app_id host_path container_path])
  end

  def succeeded!
    storage_mount.update!(status: restart ? :active : :configured)
  end

  def failed!
    storage_mount.error!
  end

  def execute!(ssh)
    @ssh = ssh
    phases = storage_phase_bindings
    validate_storage_scope!(phases)
    if phases.values.any? { |mounts| mounts.any? { |mount| mount["container_path"] == container_path && mount["host_path"] != host_path } }
      raise "Container path is already mounted from another directory"
    end
    missing = phases.select { |phase, mounts| !binding_present?(mounts) }.keys
    if missing.any?
      ssh.execute!("test -d #{Shellwords.escape(host_path)}") unless managed_host_path?
      name = storage_entry_name(phases)
      ssh.execute!(Dokku::Storage::Mount.new(app: dokku_app_id, entry_name: name, container_directory: container_path))
    end
    ssh.execute!(Dokku::Ps::RestartCommand.new(app: dokku_app_id)) if restart
    unless storage_phase_bindings.values.all? { |mounts| binding_present?(mounts) }
      raise "Storage mount was not confirmed by Dokku in deploy and run"
    end
  end

  private

  def managed_host_path?
    host_path.match?(%r{\A/var/lib/dokku/data/storage/watergun-[a-f0-9]{32}\z})
  end

  def storage_entry_name(phases)
    binding = phases.values.flatten.find { |mount| binding_present?([mount]) }
    return binding.fetch("entry_name") if binding

    entries = ssh.execute!(Dokku::Storage::ListEntriesCommand.new).parsed_output
    entry = entries.find { |item| item["host_path"] == host_path }
    return entry.fetch("name") if entry

    name = managed_host_path? ? File.basename(host_path) : "watergun-#{Digest::SHA256.hexdigest(host_path).first(32)}"
    raise "Storage entry name is already registered for another directory" if entries.any? { |item| item["name"] == name }

    if managed_host_path?
      ssh.execute!(Dokku::Storage::CreateEntry.new(name: name, chown: chown))
    else
      # Register the exact retained path; never create a replacement or chown it.
      ssh.execute!(Dokku::Storage::CreateEntry.new(name: name, path: host_path))
    end
    name
  end
end
