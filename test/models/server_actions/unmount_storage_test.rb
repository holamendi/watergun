require "test_helper"

class ServerActions::UnmountStorageTest < ActiveSupport::TestCase
  include SshTestHelper
  include StoragePhaseTestHelper

  test "partial unmount failure reconciles run phase on retry" do
    action = ServerActions::UnmountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = storage_phase_session(@storage_mount, attached: true)
    session.fail_run_once = true
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert_equal "detach_failed", @storage_mount.reload.status
    assert_not_equal session.bindings["deploy"], session.bindings["run"]
    action.run
    assert_equal session.bindings["deploy"], session.bindings["run"]
    assert_equal "detached", @storage_mount.reload.status
  end

  test "unmount verifies run phase before reporting success" do
    action = ServerActions::UnmountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = storage_phase_session(@storage_mount, attached: true)
    session.ignore_run_change = true
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert_equal "detach_failed", @storage_mount.reload.status
  end

  def setup
    Ssh::Session.name
    @app = apps(:domain_test_app)
    @server = @app.server
    @storage_mount = @app.storage_mounts.create!(container_path: "/app/uploads", status: :active)
  end

  test "unmounts restarts verifies and retains record for reattachment" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      ordered: true,
      commands: [
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: [{host_path: @storage_mount.host_path, container_path: @storage_mount.container_path}].to_json},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: [{host_path: @storage_mount.host_path, container_path: @storage_mount.container_path}].to_json},
        {cmd: "dokku docker-options:remove domain-test-app deploy -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku docker-options:remove domain-test-app run -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku ps:restart domain-test-app"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: "[]"}
      ]
    )

    path = @storage_mount.host_path
    assert_no_difference -> { StorageMount.count } do
      action = ServerActions::UnmountStorage.run_now!(@server, @storage_mount, restart: true)
      assert action.success?
    end
    assert_equal "detached", @storage_mount.reload.status
    assert_not @storage_mount.discarded?
    assert_equal path, @storage_mount.host_path
  end

  test "detach retry skips absent binding and still restarts and verifies" do
    action = ServerActions::UnmountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(stub(parsed_output: []))
    session.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    session.expects(:execute!).with(instance_of(Dokku::Storage::UnmountCommand)).never
    action.ssh_session = session
    action.run
    assert_equal "detached", @storage_mount.reload.status
  end

  test "verification failure preserves record and failed detach intent" do
    action = ServerActions::UnmountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    session.stubs(:execute!).returns(stub(parsed_output: [{"host_path" => @storage_mount.host_path, "container_path" => @storage_mount.container_path}]))
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert_equal "detach_failed", @storage_mount.reload.status
    assert_not @storage_mount.discarded?
  end

  test "restart failure after unmount preserves retryable detach intent" do
    mock_ssh_session(host: @server.public_ip, user: SshKey::USER, port: @server.ssh_port, private_key: @server.ssh_key.private_key,
      ordered: true,
      commands: [
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: [{host_path: @storage_mount.host_path, container_path: @storage_mount.container_path}].to_json},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: [{host_path: @storage_mount.host_path, container_path: @storage_mount.container_path}].to_json},
        {cmd: "dokku docker-options:remove domain-test-app deploy -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku docker-options:remove domain-test-app run -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku ps:restart domain-test-app", exit_code: 1}
      ])
    action = ServerActions::UnmountStorage.run_now!(@server, @storage_mount, restart: true)
    assert action.failure?
    assert_equal "detach_failed", @storage_mount.reload.status
    assert_not @storage_mount.discarded?
  end

  test "marks storage mount as error on ssh failure" do
    stub_session = Class.new do
      def exec!(_cmd, status:)
        status[:exit_code] = 1
        yield(nil, :stderr, "Error unmounting storage") if block_given?
      end

      def loop
      end
    end.new

    Net::SSH.expects(:start)
      .with(@server.public_ip, SshKey::USER,
        port: @server.ssh_port,
        key_data: [@server.ssh_key.private_key],
        keys_only: true,
        non_interactive: true)
      .yields(stub_session)

    server_action = ServerActions::UnmountStorage.run_now!(@server, @storage_mount, restart: true)

    assert server_action.failure?
    assert_equal "detach_failed", @storage_mount.reload.status
  end
end
