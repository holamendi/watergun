class StorageMount::DestroyStorageMount
  def initialize(storage_mount)
    @storage_mount = storage_mount
  end

  def destroy
    @storage_mount.with_lock do
      return false unless @storage_mount.active? || @storage_mount.error?
      return false if @storage_mount.server_actions.queued_or_running.exists?

      @storage_mount.detaching!
      ServerActions::UnmountStorage.run_later!(@storage_mount.server, @storage_mount)
    end
    true
  end
end
