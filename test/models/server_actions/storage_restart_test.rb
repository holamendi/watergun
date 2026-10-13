require "test_helper"

class ServerActions::StorageRestartTest < ActiveSupport::TestCase
  include StoragePhaseTestHelper

  test "no restart still detects failed run phase verification and remains intent aware" do
    {"apps.mount_storage" => "error", "apps.unmount_storage" => "detach_failed"}.each do |action_key, status|
      app = apps(:domain_test_app)
      mount = app.storage_mounts.create!(container_path: "/app/#{status}")
      session = storage_phase_session(mount, attached: action_key == "apps.unmount_storage")
      session.ignore_run_change = true
      action = create_server_action_run(action_key, server: app.server, target: mount)
      action_operation = ServerAction::Registry.build(action)
      assert_raises(RuntimeError) { perform_server_operation(action_operation, session) }
      assert_equal status, mount.reload.status
      assert_not session.commands.any? { |tokens| tokens.include?("ps:restart") }
      session.ignore_run_change = false
      perform_server_operation(action_operation, session)
      assert_equal (action_key == "apps.mount_storage") ? "configured" : "detach_configured", mount.reload.status
      assert_equal session.bindings["deploy"], session.bindings["run"]
      assert_not session.commands.any? { |tokens| tokens.include?("ps:restart") }
    end
  end

  test "default operations reconcile and verify both phases without restarting" do
    {"apps.mount_storage" => "configured", "apps.unmount_storage" => "detach_configured"}.each do |action_key, status|
      app = apps(:domain_test_app)
      mount = app.storage_mounts.create!(container_path: "/app/#{status}")
      session = storage_phase_session(mount, attached: action_key == "apps.unmount_storage")
      action = create_server_action_run(action_key, server: app.server, target: mount)
      action_operation = ServerAction::Registry.build(action)
      perform_server_operation(action_operation, session)
      assert_equal status, mount.reload.status
      assert_equal false, action.reload.payload["restart"]
      assert_equal 4, session.commands.count { |tokens| tokens.include?("storage-app-mounts") }
      assert_not session.commands.any? { |tokens| tokens.include?("ps:restart") }
      assert_not mount.discarded?
    end
  end
end
