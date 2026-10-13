class StorageMount::DestroyStorageMount
  def initialize(storage_mount)
    @storage_mount = storage_mount
  end

  def destroy(restart: false)
    @storage_mount.with_lock do
      return false unless @storage_mount.active? || @storage_mount.configured? || @storage_mount.detach_configured? || @storage_mount.error?
      return false if @storage_mount.server_action_runs.queued_or_running.exists?

      @storage_mount.detaching!
      ServerAction::Enqueue.call(action: "apps.unmount_storage", target: @storage_mount, payload: {restart: restart})
    end
    true
  end
end
