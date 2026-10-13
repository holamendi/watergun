require "test_helper"

class ServerActions::StorageRestartTest < ActiveSupport::TestCase
  include StoragePhaseTestHelper

  test "no restart still detects failed run phase verification and remains intent aware" do
    {ServerActions::MountStorage => "error", ServerActions::UnmountStorage => "detach_failed"}.each do |klass, status|
      app = apps(:domain_test_app)
      mount = app.storage_mounts.create!(container_path: "/app/#{status}")
      session = storage_phase_session(mount, attached: klass == ServerActions::UnmountStorage)
      session.ignore_run_change = true
      action = create_server_action_run(klass, server: app.server, target: mount)
      action_operation = ServerAction::Registry.build(action)
      assert_raises(RuntimeError) { perform_server_operation(action_operation, session) }
      assert_equal status, mount.reload.status
      assert_not session.commands.any? { |tokens| tokens.include?("ps:restart") }
      session.ignore_run_change = false
      perform_server_operation(action_operation, session)
      assert_equal (klass == ServerActions::MountStorage) ? "configured" : "detach_configured", mount.reload.status
      assert_equal session.bindings["deploy"], session.bindings["run"]
      assert_not session.commands.any? { |tokens| tokens.include?("ps:restart") }
    end
  end

  test "default operations reconcile and verify both phases without restarting" do
    {ServerActions::MountStorage => "configured", ServerActions::UnmountStorage => "detach_configured"}.each do |klass, status|
      app = apps(:domain_test_app)
      mount = app.storage_mounts.create!(container_path: "/app/#{status}")
      session = storage_phase_session(mount, attached: klass == ServerActions::UnmountStorage)
      action = create_server_action_run(klass, server: app.server, target: mount)
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
