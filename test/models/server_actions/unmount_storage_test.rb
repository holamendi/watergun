require "test_helper"

class ServerActions::UnmountStorageTest < ActiveSupport::TestCase
  include SshTestHelper

  def setup
    @app = apps(:domain_test_app)
    @server = @app.server
    @storage_mount = @app.storage_mounts.create!(container_path: "/app/uploads", status: :active)
  end

  test "unmounts storage and destroys record" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku storage:unmount domain-test-app #{@storage_mount.host_path}:/app/uploads"}
      ]
    )

    assert_difference -> { StorageMount.count }, -1 do
      ServerActions::UnmountStorage.run_now!(@server, @storage_mount)
    end
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

    server_action = ServerActions::UnmountStorage.run_now!(@server, @storage_mount)

    assert server_action.failure?
    assert @storage_mount.reload.error?
  end
end
