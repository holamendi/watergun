require "test_helper"

class Projects::Apps::StorageMountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @app = apps(:domain_test_app)
    @user = users(:bobby)

    sign_in @user
  end

  describe "#index" do
    test "renders storage page with settings sidebar" do
      get project_app_storage_mounts_path(@project, @app)

      assert_response :success
      assert_select "h1", text: "Storage"
      assert_select "nav[aria-label='Settings navigation']"
      assert_select "[data-ui-component='page-header']"
      assert_select "button[data-ui-component='modal-trigger']"
      assert_select "#storage_mounts"
    end
  end

  describe "#create" do
    test "creates storage mount and schedules server action" do
      assert_difference -> { StorageMount.count } do
        post project_app_storage_mounts_path(@project, @app), params: {
          storage_mount: {container_path: "/app/data"}
        }, as: :turbo_stream
      end

      mount = StorageMount.last
      assert_equal "/app/data", mount.container_path
      assert mount.host_path.present?
      assert_equal "pending", mount.status

      server_action = ServerAction.find_by(type: "ServerActions::MountStorage", actionable: mount)
      assert server_action
    end

    test "rejects invalid container path" do
      assert_no_difference -> { StorageMount.count } do
        post project_app_storage_mounts_path(@project, @app), params: {
          storage_mount: {container_path: "not-absolute"}
        }, as: :turbo_stream
      end

      assert_response :success
    end
  end

  describe "#destroy" do
    test "soft-deletes storage mount and schedules unmount" do
      mount = @app.storage_mounts.create!(container_path: "/app/temp", status: :active)

      delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream

      assert_response :success
      assert mount.reload.discarded?

      server_action = ServerAction.find_by(type: "ServerActions::UnmountStorage", actionable: mount)
      assert server_action
    end
  end
end
