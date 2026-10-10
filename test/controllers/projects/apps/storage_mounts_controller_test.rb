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

  test "reattaches retained mount with unchanged backing path" do
    mount = @app.storage_mounts.create!(container_path: "/app/retained", status: :detached, chown: "heroku")
    host_path = mount.host_path
    assert_difference -> { ServerActions::MountStorage.count } do
      patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    end
    assert_response :success
    assert_equal "pending", mount.reload.status
    assert_equal host_path, mount.host_path
    assert_equal "heroku", mount.chown
  end

  test "retries failed mount or detach according to retained intent" do
    {error: ServerActions::MountStorage, detach_failed: ServerActions::UnmountStorage}.each do |status, klass|
      mount = @app.storage_mounts.create!(container_path: "/app/#{status}", status: status)
      assert_difference -> { klass.count } do
        patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
      end
      assert_response :success
      assert_equal (status == :error) ? "pending" : "detaching", mount.reload.status
      assert_no_difference -> { ServerAction.count } do
        patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
      end
      assert_response :conflict
    end
  end

  test "accepts Dockerfile ownership preset but ignores submitted host paths" do
    @app.update!(builder: :dockerfile)
    post project_app_storage_mounts_path(@project, @app), params: {storage_mount: {container_path: "/app/owned", chown: "heroku", host_path: "/etc"}}, as: :turbo_stream
    assert_response :success
    mount = @app.storage_mounts.find_by!(container_path: "/app/owned")
    assert_equal "heroku", mount.chown
    assert_match %r{\A/var/lib/dokku/data/storage/watergun-}, mount.host_path
  end

  test "storage UI shows truthful states retention actions and ownership warnings" do
    @app.storage_mounts.create!(container_path: "/app/retained", status: :detached)
    @app.storage_mounts.create!(container_path: "/app/failed", status: :error)
    @app.storage_mounts.create!(container_path: "/app/detach_failed", status: :detach_failed)
    get project_app_storage_mounts_path(@project, @app)
    assert_response :success
    assert_select "a", text: "Detach (keep data)"
    assert_select "a", text: "Reattach"
    assert_select "a", text: "Retry mount"
    assert_select "a", text: "Retry detach"
    assert_select "select[name='storage_mount[chown]']"
    assert_includes response.body, "hides existing image contents"
    assert_includes response.body, "automatically restarts"
    assert_includes response.body, "Mount failed; state unconfirmed"
    assert_includes response.body, "Detach failed; state unconfirmed"
  end

  test "tenant and app scopes reject mount IDs and project IDs from outside request scope" do
    other_account = Account.create!(name: "Other tenant")
    other_project = other_account.projects.create!(name: "Other project", server: @app.server)
    other_app = other_project.apps.create!(name: "Other app")
    other_mount = other_app.storage_mounts.create!(container_path: "/app/tenant", status: :detached)
    sibling_mount = apps(:smol_roda).storage_mounts.create!(container_path: "/app/sibling", status: :active)
    assert_no_difference -> { ServerAction.count } do
      patch project_app_storage_mount_path(@project, @app, other_mount), as: :turbo_stream
      assert_response :not_found
      delete project_app_storage_mount_path(@project, @app, sibling_mount), as: :turbo_stream
      assert_response :not_found
      patch project_app_storage_mount_path(other_project, other_app, other_mount), as: :turbo_stream
      assert_response :not_found
      post project_app_storage_mounts_path(other_project, other_app), params: {storage_mount: {container_path: "/data"}}, as: :turbo_stream
      assert_response :not_found
    end
    assert_equal "detached", other_mount.reload.status
    assert_equal "active", sibling_mount.reload.status
  end

  test "create rolls back retained record when operation cannot be queued" do
    ServerActions::MountStorage.stubs(:run_later!).raises(RuntimeError, "queue unavailable")
    assert_no_difference -> { StorageMount.count } do
      assert_raises(RuntimeError) do
        post project_app_storage_mounts_path(@project, @app), params: {storage_mount: {container_path: "/app/queue_failure"}}, as: :turbo_stream
      end
    end
  end

  describe "#destroy" do
    test "retains storage mount while scheduling keep-data detach" do
      mount = @app.storage_mounts.create!(container_path: "/app/temp", status: :active)

      delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream

      assert_response :success
      assert_not mount.reload.discarded?
      assert_equal "detaching", mount.status

      server_action = ServerAction.find_by(type: "ServerActions::UnmountStorage", actionable: mount)
      assert server_action
      assert_includes response.body, "Detach queued; data will be kept and app will restart"
      assert_no_difference -> { ServerAction.count } do
        delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
      end
      assert_response :conflict
    end
  end
end
