require "test_helper"

class ServerActions::MountStorageTest < ActiveSupport::TestCase
  include SshTestHelper
  include ServerActionTestHelper

  def setup
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
      commands: [
        {cmd: "dokku storage:ensure_directory domain-test-app --chown=herokuish"},
        {cmd: "dokku storage:mount domain-test-app #{@storage_mount.host_path}:/app/uploads"}
      ]
    )

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount)

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

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount)

    assert server_action.failure?
    assert @storage_mount.reload.error?
  end

  test "stores payload attributes from storage mount" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku storage:ensure_directory domain-test-app --chown=herokuish"},
        {cmd: "dokku storage:mount domain-test-app #{@storage_mount.host_path}:/app/uploads"}
      ]
    )

    server_action = ServerActions::MountStorage.run_now!(@server, @storage_mount)

    assert_equal "domain-test-app", server_action.dokku_app_id
    assert_equal @storage_mount.host_path, server_action.host_path
    assert_equal "/app/uploads", server_action.container_path
    assert_equal "herokuish", server_action.chown
  end
end
