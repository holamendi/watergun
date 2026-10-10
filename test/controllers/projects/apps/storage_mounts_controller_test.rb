require "test_helper"

class Projects::Apps::StorageMountsControllerTest < ActionDispatch::IntegrationTest
  include StoragePhaseTestHelper
  include ActionView::RecordIdentifier

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

  test "every storage request stores an explicit typed restart preference" do
    [nil, "0", "false", "off", "1"].each_with_index do |value, index|
      preference = value == "1"
      post project_app_storage_mounts_path(@project, @app), params: {storage_mount: {container_path: "/app/preference_#{index}", restart: value}}, as: :turbo_stream
      assert_response :success
      mount = @app.storage_mounts.find_by!(container_path: "/app/preference_#{index}")
      assert_restart_operation(mount.server_actions.last, preference)
      mount.server_actions.update_all(status: :success)
      mount.update!(status: :active)
      delete project_app_storage_mount_path(@project, @app, mount), params: {storage_mount: {restart: value}}, as: :turbo_stream
      assert_response :success
      assert_restart_operation(mount.server_actions.last, preference)
      [:detached, :error, :detach_failed].each do |status|
        mount.server_actions.update_all(status: :success)
        mount.update!(status: status)
        patch project_app_storage_mount_path(@project, @app, mount), params: {storage_mount: {restart: value}}, as: :turbo_stream
        assert_response :success
        action = mount.server_actions.last
        assert_restart_operation(action, preference)
        assert_equal (status == :detach_failed) ? "ServerActions::UnmountStorage" : "ServerActions::MountStorage", action.type
      end
    end
  end

  test "empty storage UI has no explanatory paragraph" do
    @app.storage_mounts.destroy_all
    get project_app_storage_mounts_path(@project, @app)
    assert_response :success
    assert_not_includes response.body, "Add a persistent storage mount to preserve data across deployments."
  end

  test "queued notifications do not promise a restart" do
    mount = @app.storage_mounts.create!(container_path: "/app/toast", status: :detached)
    patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :success
    assert_not_includes response.body, "app will restart"
    mount.server_actions.update_all(status: :success)
    mount.active!
    delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :success
    assert_includes response.body, "Detach queued"
    assert_not_includes response.body, "app will restart"
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

  test "configured attachment and detachment stay operable with scoped intent" do
    mount = @app.storage_mounts.create!(container_path: "/app/configured", status: :configured)
    delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :success
    assert_equal "ServerActions::UnmountStorage", mount.server_actions.last.type
    mount.server_actions.update_all(status: :success)
    mount.update!(status: :detach_configured)
    patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :success
    assert_equal "ServerActions::MountStorage", mount.server_actions.last.type
    mount.server_actions.update_all(status: :success)
    mount.update!(status: :configured)
    patch project_app_storage_mount_path(@project, @app, mount), params: {storage_mount: {restart: "1"}}, as: :turbo_stream
    assert_response :success
    assert_equal "ServerActions::MountStorage", mount.server_actions.last.type
    assert_equal true, mount.server_actions.last.payload["restart"]
    mount.server_actions.update_all(status: :success)
    mount.update!(status: :detach_configured)
    delete project_app_storage_mount_path(@project, @app, mount), params: {storage_mount: {restart: "1"}}, as: :turbo_stream
    assert_response :success
    assert_equal "ServerActions::UnmountStorage", mount.server_actions.last.type
    assert_equal true, mount.server_actions.last.payload["restart"]
  end

  test "accepts Dockerfile ownership preset but ignores submitted host paths" do
    @app.update!(builder: :dockerfile)
    post project_app_storage_mounts_path(@project, @app), params: {storage_mount: {container_path: "/app/owned", chown: "heroku", host_path: "/etc"}}, as: :turbo_stream
    assert_response :success
    mount = @app.storage_mounts.find_by!(container_path: "/app/owned")
    assert_equal "heroku", mount.chown
    assert_match %r{\A/var/lib/dokku/data/storage/watergun-}, mount.host_path
  end

  test "storage UI uses concise forms unchecked restart options and pending restart labels" do
    [:detached, :error, :detach_failed, :configured, :detach_configured].each do |status|
      @app.storage_mounts.create!(container_path: "/app/#{status}", status: status)
    end
    get project_app_storage_mounts_path(@project, @app)
    assert_response :success
    ["Detach (keep data)", "Reattach", "Retry mount", "Retry detach", "Apply mount", "Apply detach", "Add mount"].each do |label|
      assert_select "button", text: label
    end
    assert_select "select[name='storage_mount[chown]']"
    assert_select "input[type='checkbox'][name='storage_mount[restart]']", count: 10
    assert_select "input[type='checkbox'][name='storage_mount[restart]'][checked]", count: 0
    assert_select "label", text: "Restart app", count: 10
    assert_select "label.restart-option", text: "Restart app", count: 10
    assert_select "[data-turbo-confirm]", count: 0
    ["Storage mounts persist", "hides existing image contents", "automatically restarts", "For non-root Dockerfile", "Adding storage restarts", "Data is retained. Retry", "Detached; backing data retained", "Add mount and restart"].each do |text|
      assert_not_includes response.body, text
    end
    assert_select ".badge-warning", text: "Restart pending"
    assert_select ".badge-warning", text: "Detach pending"
    assert_select ".badge-error", text: "Mount failed"
    assert_select ".badge-error", text: "Detach failed"
  end

  test "storage rows isolate restart controls in accessible action dialogs" do
    mount = storage_mounts(:uploads_mount)
    mount.update!(status: :configured, chown: "heroku")
    get project_app_storage_mounts_path(@project, @app)
    assert_response :success
    assert_select "##{dom_id(mount)} .storage-mount-row" do
      assert_select "input", count: 0
      assert_select "form", count: 0
      assert_select ".storage-host-path[title=?]", mount.host_path
      assert_select ".storage-ownership", text: "UID:GID 1000:1000"
      assert_select ".badge-warning", text: "Restart pending"
      assert_select ".action-dropdown", count: 1
      assert_select "button[data-controller='dialog-trigger']", count: 2
    end
    ["resume", "detach"].each do |action|
      assert_select "dialog##{dom_id(mount, "#{action}_modal")}" do
        assert_select ".storage-dialog-target", text: mount.container_path
        assert_select "input[type='checkbox'][name='storage_mount[restart]']:not([checked])", count: 1
        assert_select ".storage-dialog-footer button[type='submit']", count: 1
        assert_select ".storage-dialog-footer button[data-action='dialog#close']", text: "Cancel"
      end
    end
    ids = css_select("[id]").map { |element| element["id"] }
    assert_equal ids.uniq, ids
    assert_select "label[for='storage_mount_container_path']", text: "Container path"
  end

  test "storage statuses use semantic colors and busy rows do not offer conflicting actions" do
    {error: ["Mount failed", "error"], detach_failed: ["Detach failed", "error"], detached: ["Retained", "neutral"], pending: ["Mounting", "warning"], detaching: ["Detaching", "warning"], detach_configured: ["Detach pending", "warning"]}.each do |status, (label, color)|
      mount = storage_mounts(:uploads_mount)
      mount.update!(status: status)
      get project_app_storage_mounts_path(@project, @app)
      assert_select "##{dom_id(mount)} .badge-#{color}", text: label
      if [:pending, :detaching].include?(status)
        assert_select "##{dom_id(mount)} button", count: 0
      end
    end
  end

  test "successful row actions close the specific dialog before replacing its mount collection" do
    mount = storage_mounts(:uploads_mount)
    mount.update!(status: :detached)
    patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action='close_dialog'][target='#{dom_id(mount, :resume_modal)}']"
    assert_operator response.body.index('action="close_dialog"'), :<, response.body.index('target="storage_mounts"')
    mount.server_actions.update_all(status: :success)
    mount.update!(status: :active)
    delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action='close_dialog'][target='#{dom_id(mount, :detach_modal)}']"
    assert_operator response.body.index('action="close_dialog"'), :<, response.body.index('target="storage_mounts"')
    patch project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
    assert_response :conflict
    assert_not_includes response.body, "close_dialog"
  end

  test "tenant and app scopes reject mount IDs and project IDs from outside request scope" do
    other_account = Account.create!(name: "Other tenant")
    other_project = other_account.projects.create!(name: "Other project", server: @app.server)
    other_app = other_project.apps.create!(name: "Other app")
    other_mount = other_app.storage_mounts.create!(container_path: "/app/tenant", status: :detach_configured)
    sibling_mount = apps(:smol_roda).storage_mounts.create!(container_path: "/app/sibling", status: :configured)
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
    assert_equal "detach_configured", other_mount.reload.status
    assert_equal "configured", sibling_mount.reload.status
  end

  test "create rolls back retained record when operation cannot be queued" do
    ServerActions::MountStorage.stubs(:run_later!).raises(RuntimeError, "queue unavailable")
    assert_no_difference -> { StorageMount.count } do
      assert_raises(RuntimeError) do
        post project_app_storage_mounts_path(@project, @app), params: {storage_mount: {container_path: "/app/queue_failure"}}, as: :turbo_stream
      end
    end
  end

  private def assert_restart_operation(action, preference)
    assert_equal preference, action.payload["restart"]
    attaching = action.is_a?(ServerActions::MountStorage)
    session = storage_phase_session(action.actionable, attached: !attaching)
    action.ssh_session = session
    action.run
    assert_equal preference ? 1 : 0, session.commands.count { |tokens| tokens.include?("ps:restart") }
    assert_equal 4, session.commands.count { |tokens| tokens.include?("storage-app-mounts") }
    expected_status = if attaching
      preference ? "active" : "configured"
    else
      preference ? "detached" : "detach_configured"
    end
    assert_equal expected_status, action.actionable.reload.status
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
      assert_includes response.body, "Detach queued"
      assert_no_difference -> { ServerAction.count } do
        delete project_app_storage_mount_path(@project, @app, mount), as: :turbo_stream
      end
      assert_response :conflict
    end
  end
end
