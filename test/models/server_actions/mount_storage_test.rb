require "test_helper"

class ServerActions::MountStorageTest < ActiveSupport::TestCase
  include SshTestHelper
  include StoragePhaseTestHelper
  include ServerActionTestHelper

  test "legacy unusual paths are preserved and shell encoded throughout recovery" do
    @storage_mount.update_columns(container_path: "/app/a file$(id);'[]#.^$/", host_path: "/var/lib/dokku/data/storage/old file$(id);'[]#.^$")
    path = @storage_mount.host_path
    session = storage_phase_session(@storage_mount)
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    action.ssh_session = session
    action.run
    assert @storage_mount.reload.active?
    assert_includes session.commands, ["test", "-d", path]
    assert_includes session.commands, ["dokku", "docker-options:add", @app.dokku_id, "run", "-v #{path}:#{@storage_mount.container_path}"]
    action.on_failure
    assert @storage_mount.reload.error?
    detach = ServerActions::UnmountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    detach.ssh_session = session
    detach.run
    assert @storage_mount.reload.detached?
    detach.on_failure
    assert @storage_mount.reload.detach_failed?
    assert_equal path, @storage_mount.host_path
  end

  test "partial mount failure reconciles run phase on retry" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = storage_phase_session(@storage_mount, attached: false)
    session.fail_run_once = true
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert_equal "error", @storage_mount.reload.status
    assert_not_equal session.bindings["deploy"], session.bindings["run"]
    action.run
    assert_equal session.bindings["deploy"], session.bindings["run"]
    assert_equal "active", @storage_mount.reload.status
  end

  test "mount verifies run phase before reporting success" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = storage_phase_session(@storage_mount, attached: false)
    session.ignore_run_change = true
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert_equal "error", @storage_mount.reload.status
  end

  def setup
    Ssh::Session.name
    @app = apps(:domain_test_app)
    @app.update!(builder: :herokuish)
    @server = @app.server
    @storage_mount = @app.storage_mounts.create!(container_path: "/app/uploads", status: :pending)
  end

  test "ensures directory and mounts storage, marks as active" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      ordered: true,
      commands: [
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: "[]"},
        {cmd: "dokku storage:ensure-directory --chown herokuish #{File.basename(@storage_mount.host_path)}"},
        {cmd: "dokku docker-options:add domain-test-app deploy -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku docker-options:add domain-test-app run -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku ps:restart domain-test-app"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: [{host_path: @storage_mount.host_path, container_path: "/app/uploads"}].to_json},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: [{host_path: @storage_mount.host_path, container_path: "/app/uploads"}].to_json}
      ]
    )

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount, restart: true)

    assert server_action.success?
    assert @storage_mount.reload.active?
  end

  test "marks storage mount as error on ssh failure" do
    stub_session = Class.new do
      def exec!(_cmd, status:)
        status[:exit_code] = 1
        yield(nil, :stderr, "Error mounting storage") if block_given?
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

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount, restart: true)

    assert server_action.failure?
    assert @storage_mount.reload.error?
  end

  test "mount retry skips already configured binding and retries restart and verification" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    list = stub(parsed_output: [{"host_path" => @storage_mount.host_path, "container_path" => @storage_mount.container_path}])
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(list)
    session.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    session.expects(:execute!).with(instance_of(Dokku::Storage::Mount)).never
    session.expects(:execute!).with(instance_of(Dokku::Storage::EnsureDirectory)).never
    action.ssh_session = session
    action.run
    assert @storage_mount.reload.active?
  end

  test "does not claim active when verification returns different mount" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    session.stubs(:execute!).returns(stub(parsed_output: [{"host_path" => "/other", "container_path" => "/app/uploads"}]))
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert @storage_mount.reload.error?
  end

  test "restart failure leaves mount retryable rather than active" do
    mock_ssh_session(host: @server.public_ip, user: SshKey::USER, port: @server.ssh_port, private_key: @server.ssh_key.private_key,
      ordered: true,
      commands: [
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: "[]"},
        {cmd: "dokku storage:ensure-directory --chown herokuish #{File.basename(@storage_mount.host_path)}"},
        {cmd: "dokku docker-options:add domain-test-app deploy -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku docker-options:add domain-test-app run -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku ps:restart domain-test-app", exit_code: 1}
      ])
    action = ServerActions::MountStorage.run_now!(@server, @storage_mount, restart: true)
    assert action.failure?
    assert @storage_mount.reload.error?
  end

  test "connection failures before run leave storage retryable" do
    [ServerActions::MountStorage, ServerActions::UnmountStorage].each do |klass|
      @storage_mount.update!(status: (klass == ServerActions::MountStorage) ? :pending : :detaching)
      action = klass.create!(server: @server, actionable: @storage_mount, restart: true)
      action.server.stubs(:ssh_session).raises(Net::SSH::ConnectionTimeout, "unreachable")
      assert_raises(Net::SSH::ConnectionTimeout) { action.run_now }
      assert_equal (klass == ServerActions::MountStorage) ? "error" : "detach_failed", @storage_mount.reload.status
      assert action.reload.finished?
    end
  end

  test "reattaching legacy backing paths checks exact directory without creating a different one" do
    @storage_mount.update_column(:host_path, "/var/lib/dokku/data/storage/domain-test-app/app_uploads")
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(stub(parsed_output: []), stub(parsed_output: []), stub(parsed_output: [{"host_path" => @storage_mount.host_path, "container_path" => @storage_mount.container_path}]))
    session.expects(:execute!).with("test -d #{@storage_mount.host_path}")
    session.expects(:execute!).with(instance_of(Dokku::Storage::Mount)).twice
    session.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    session.expects(:execute!).with(instance_of(Dokku::Storage::EnsureDirectory)).never
    action.ssh_session = session
    action.run
    assert @storage_mount.reload.active?
  end

  test "successful mount command is not active until final verification confirms exact binding" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(stub(parsed_output: []))
    session.expects(:execute!).with(instance_of(Dokku::Storage::EnsureDirectory))
    session.expects(:execute!).with(instance_of(Dokku::Storage::Mount)).twice
    session.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert @storage_mount.reload.error?
  end

  test "malformed verification JSON leaves operation retryable" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    result = mock
    result.expects(:parsed_output).raises(JSON::ParserError, "invalid JSON")
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).returns(result)
    action.ssh_session = session
    assert_raises(JSON::ParserError) { action.run }
    assert @storage_mount.reload.error?
  end

  test "stores payload attributes from storage mount" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      ordered: true,
      commands: [
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: "[]"},
        {cmd: "dokku storage:ensure-directory --chown herokuish #{File.basename(@storage_mount.host_path)}"},
        {cmd: "dokku docker-options:add domain-test-app deploy -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku docker-options:add domain-test-app run -v\\ #{@storage_mount.host_path}:/app/uploads"},
        {cmd: "dokku ps:restart domain-test-app"},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app deploy json", stdout: [{host_path: @storage_mount.host_path, container_path: "/app/uploads"}].to_json},
        {cmd: "sudo -n dokku plugin:trigger storage-list domain-test-app run json", stdout: [{host_path: @storage_mount.host_path, container_path: "/app/uploads"}].to_json}
      ]
    )

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount, restart: true)

    assert_equal "domain-test-app", server_action.dokku_app_id
    assert_equal @storage_mount.host_path, server_action.host_path
    assert_equal "/app/uploads", server_action.container_path
    assert_equal "herokuish", server_action.chown
  end
end
