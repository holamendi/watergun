class StorageMount::DestroyStorageMount
  def initialize(storage_mount)
    @storage_mount = storage_mount
  end

  def destroy
    @storage_mount.discard
    ServerActions::UnmountStorage.run_later!(@storage_mount.server, @storage_mount)
  end
end
