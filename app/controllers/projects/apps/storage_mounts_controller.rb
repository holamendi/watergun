class Projects::Apps::StorageMountsController < Projects::Apps::BaseController
  before_action :set_storage_mount, only: %i[update destroy]

  def index
    @storage_mounts = storage_mounts_scope
  end

  def create
    @storage_mount = @app.storage_mounts.new(storage_mount_params)

    if @storage_mount.save_and_mount(restart: restart_requested?)
      render turbo_stream: [
        stream_toast("Storage mount added"),
        stream_storage_mounts,
        turbo_stream.action(:close_dialog, helpers.dom_id(@app, :storage_mount_modal))
      ]
    else
      render turbo_stream: turbo_stream.replace(
        "storage_mount_form",
        partial: "projects/apps/storage_mounts/form",
        locals: {storage_mount: @storage_mount}
      )
    end
  end

  def update
    if @storage_mount.resume(restart: restart_requested?)
      render turbo_stream: [stream_toast("Storage operation queued"), stream_storage_mounts]
    else
      head :conflict
    end
  end

  def destroy
    if StorageMount::DestroyStorageMount.new(@storage_mount).destroy(restart: restart_requested?)
      render turbo_stream: [
        stream_toast("Detach queued"),
        stream_storage_mounts
      ]
    else
      head :conflict
    end
  end

  private

  def set_storage_mount
    @storage_mount = @app.storage_mounts.kept.find(params[:id])
  end

  def restart_requested?
    ActiveModel::Type::Boolean.new.cast(params.dig(:storage_mount, :restart)) == true
  end

  def storage_mount_params
    params.require(:storage_mount).permit(:container_path, :chown)
  end

  def storage_mounts_scope
    @app.storage_mounts.kept
  end

  def stream_storage_mounts
    turbo_stream.replace(
      "storage_mounts",
      partial: "projects/apps/storage_mounts/storage_mounts",
      locals: {
        project: @project,
        app: @app,
        storage_mounts: storage_mounts_scope,
        modal_id: helpers.dom_id(@app, :storage_mount_modal)
      }
    )
  end
end
