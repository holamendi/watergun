class ServerActions::MountStorage < ServerAction
  SLUG = "apps.mount_storage"

  actionable StorageMount

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

  def run
    ensure_directory!
    mount_storage!
  rescue Ssh::CommandExecutionError
    storage_mount.error!
    raise
  else
    storage_mount.active!
  end

  private

  def ensure_directory!
    execute!(Dokku::Storage::EnsureDirectory.new(directory: dokku_app_id, chown: chown))
  end

  def mount_storage!
    execute!(Dokku::Storage::Mount.new(app: dokku_app_id, host_directory: host_path, container_directory: container_path))
  end
end
