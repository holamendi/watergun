class Projects::Apps::StorageMountsController < Projects::Apps::BaseController
  before_action :set_storage_mount, only: :destroy

  def index
    @storage_mounts = @app.storage_mounts.kept
  end

  def create
    @storage_mount = @app.storage_mounts.new(storage_mount_params)

    if @storage_mount.save
      ServerActions::MountStorage.run_later!(@app.server, @storage_mount)
      render turbo_stream: [
        stream_toast("Storage mount added"),
        turbo_stream.replace("storage_mounts", partial: "projects/apps/storage_mounts/storage_mounts", locals: {app: @app})
      ]
    else
      render turbo_stream: turbo_stream.replace(
        "storage_mount_form",
        partial: "projects/apps/storage_mounts/form",
        locals: {storage_mount: @storage_mount}
      )
    end
  end

  def destroy
    StorageMount::DestroyStorageMount.new(@storage_mount).destroy
    render turbo_stream: [
      stream_toast("Storage mount removed"),
      turbo_stream.remove(@storage_mount)
    ]
  end

  private

  def set_storage_mount
    @storage_mount = @app.storage_mounts.kept.find(params[:id])
  end

  def storage_mount_params
    params.require(:storage_mount).permit(:container_path)
  end
end
