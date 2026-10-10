require "test_helper"

class ServerActions::MountStorageTest < ActiveSupport::TestCase
  include SshTestHelper
  include StoragePhaseTestHelper
  include ServerActionTestHelper

  test "new storage uses one native named attachment and retains its generated host path" do
    session = storage_phase_session(@storage_mount)
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount)
    action.ssh_session = session
    assert_nothing_raised { action.run }
    name = File.basename(@storage_mount.host_path)
    assert_includes session.commands, ["dokku", "storage:create", name, "--chown", "herokuish"]
    assert_equal 1, session.commands.count { |tokens| tokens[1] == "storage:mount" }
    assert_includes session.commands, ["dokku", "storage:mount", @app.dokku_id, name, "--container-dir", "/app/uploads", "--phase", "deploy", "--phase", "run"]
    assert @storage_mount.reload.configured?
  end

  test "phase repair targets the actual migrated entry without redefining its host directory" do
    session = storage_phase_session(@storage_mount, attached: true)
    session.bindings["deploy"].first["entry_name"] = "legacy-migrated"
    session.entries.first["name"] = "legacy-migrated"
    session.bindings["run"] = []
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount)
    action.ssh_session = session
    action.run
    assert_equal "legacy-migrated", session.bindings["run"].first.fetch("entry_name")
    assert_equal 1, session.commands.count { |tokens| tokens[1] == "storage:mount" }
    assert_not session.commands.any? { |tokens| tokens[1] == "storage:create" }
  end

  test "detached migrated storage reuses registered entry instead of creating or relocating data" do
    session = storage_phase_session(@storage_mount)
    session.entries << {"name" => "legacy-retained", "host_path" => @storage_mount.host_path, "scheduler" => "docker-local"}
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount)
    action.ssh_session = session
    action.run
    assert_equal "legacy-retained", session.bindings["deploy"].first.fetch("entry_name")
    assert_not session.commands.any? { |tokens| tokens[1] == "storage:create" }
    assert_equal @storage_mount.host_path, session.bindings["run"].first.fetch("host_path")
  end

  test "unregistered custom path is checked and registered without chown or relocation" do
    @storage_mount.update_column(:host_path, "/data/old directory$(id)")
    session = storage_phase_session(@storage_mount)
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount)
    action.ssh_session = session
    action.run
    assert_includes session.commands, ["test", "-d", @storage_mount.host_path]
    create = session.commands.find { |tokens| tokens[1] == "storage:create" }
    assert_equal ["dokku", "storage:create", "watergun-#{Digest::SHA256.hexdigest(@storage_mount.host_path).first(32)}", @storage_mount.host_path], create
    assert_equal @storage_mount.host_path, session.bindings["run"].first.fetch("host_path")
  end

  test "reattaching registered custom storage checks the exact retained directory without chown" do
    @storage_mount.update_column(:host_path, "/data/retained custom")
    session = storage_phase_session(@storage_mount)
    session.entries << {"name" => "legacy-kept", "host_path" => @storage_mount.host_path, "scheduler" => "docker-local"}
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount)
    action.ssh_session = session
    action.run
    assert_includes session.commands, ["test", "-d", @storage_mount.host_path]
    assert_not session.commands.any? { |tokens| tokens[1] == "storage:create" }
    assert_equal "legacy-kept", session.bindings["run"].first["entry_name"]
  end

  test "verification rejects a process scoped attachment introduced during restart" do
    session = storage_phase_session(@storage_mount, attached: true)
    def session.execute!(command)
      result = super
      if Shellwords.split(command.cmd)[1] == "ps:restart"
        bindings.each_value { |mounts| mounts.first["process_type"] = "worker" }
      end
      result
    end
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert @storage_mount.reload.error?
  end

  test "entry name collision never redefines an unrelated retained path" do
    session = storage_phase_session(@storage_mount)
    session.entries << {"name" => File.basename(@storage_mount.host_path), "host_path" => "/data/unrelated", "scheduler" => "docker-local"}
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount)
    action.ssh_session = session
    assert_raises(RuntimeError) { action.run }
    assert_not session.commands.any? { |tokens| %w[storage:create storage:mount].include?(tokens[1]) }
    assert_equal "/data/unrelated", session.entries.first.fetch("host_path")
    assert @storage_mount.reload.error?
  end

  test "legacy unusual paths are preserved and shell encoded throughout recovery" do
    @storage_mount.update_columns(container_path: "/app/a file$(id);'[]#.^$/", host_path: "/var/lib/dokku/data/storage/old file$(id);'[]#.^$")
    path = @storage_mount.host_path
    session = storage_phase_session(@storage_mount)
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    action.ssh_session = session
    action.run
    assert @storage_mount.reload.active?
    assert_includes session.commands, ["test", "-d", path]
    assert_includes session.commands, ["dokku", "storage:mount", @app.dokku_id, "watergun-#{Digest::SHA256.hexdigest(path).first(32)}", "--container-dir", @storage_mount.container_path, "--phase", "deploy", "--phase", "run"]
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
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app deploy", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app run", stdout: "[]"},
        {cmd: "dokku storage:list-entries --scheduler docker-local --format json", stdout: "[]"},
        {cmd: "dokku storage:create #{File.basename(@storage_mount.host_path)} --chown herokuish"},
        {cmd: "dokku storage:mount domain-test-app #{File.basename(@storage_mount.host_path)} --container-dir /app/uploads --phase deploy --phase run"},
        {cmd: "dokku ps:restart domain-test-app"},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app deploy", stdout: native_storage_json(@storage_mount)},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app run", stdout: native_storage_json(@storage_mount)}
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
    list = stub(parsed_output: [{"entry_name" => File.basename(@storage_mount.host_path), "host_path" => @storage_mount.host_path, "container_path" => @storage_mount.container_path}])
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(list)
    session.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    session.expects(:execute!).with(instance_of(Dokku::Storage::Mount)).never
    session.expects(:execute!).with(instance_of(Dokku::Storage::CreateEntry)).never
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
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app deploy", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app run", stdout: "[]"},
        {cmd: "dokku storage:list-entries --scheduler docker-local --format json", stdout: "[]"},
        {cmd: "dokku storage:create #{File.basename(@storage_mount.host_path)} --chown herokuish"},
        {cmd: "dokku storage:mount domain-test-app #{File.basename(@storage_mount.host_path)} --container-dir /app/uploads --phase deploy --phase run"},
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
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(stub(parsed_output: []), stub(parsed_output: []), stub(parsed_output: [{"entry_name" => File.basename(@storage_mount.host_path), "host_path" => @storage_mount.host_path, "container_path" => @storage_mount.container_path}]))
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListEntriesCommand)).returns(stub(parsed_output: []))
    session.expects(:execute!).with("test -d #{@storage_mount.host_path}")
    session.expects(:execute!).with(instance_of(Dokku::Storage::CreateEntry))
    session.expects(:execute!).with(instance_of(Dokku::Storage::Mount)).once
    session.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    action.ssh_session = session
    action.run
    assert @storage_mount.reload.active?
  end

  test "successful mount command is not active until final verification confirms exact binding" do
    action = ServerActions::MountStorage.create!(server: @server, actionable: @storage_mount, restart: true)
    session = mock
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListCommand)).times(4).returns(stub(parsed_output: []))
    session.expects(:execute!).with(instance_of(Dokku::Storage::ListEntriesCommand)).returns(stub(parsed_output: []))
    session.expects(:execute!).with(instance_of(Dokku::Storage::CreateEntry))
    session.expects(:execute!).with(instance_of(Dokku::Storage::Mount)).once
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
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app deploy", stdout: "[]"},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app run", stdout: "[]"},
        {cmd: "dokku storage:list-entries --scheduler docker-local --format json", stdout: "[]"},
        {cmd: "dokku storage:create #{File.basename(@storage_mount.host_path)} --chown herokuish"},
        {cmd: "dokku storage:mount domain-test-app #{File.basename(@storage_mount.host_path)} --container-dir /app/uploads --phase deploy --phase run"},
        {cmd: "dokku ps:restart domain-test-app"},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app deploy", stdout: native_storage_json(@storage_mount)},
        {cmd: "sudo -n dokku plugin:trigger storage-app-mounts domain-test-app run", stdout: native_storage_json(@storage_mount)}
      ]
    )

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount, restart: true)

    assert_equal "domain-test-app", server_action.dokku_app_id
    assert_equal @storage_mount.host_path, server_action.host_path
    assert_equal "/app/uploads", server_action.container_path
    assert_equal "herokuish", server_action.chown
  end
end
