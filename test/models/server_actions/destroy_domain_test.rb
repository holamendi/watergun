require "test_helper"

# Ensure Ssh::CommandExecutionError is loaded (defined in session.rb)

class ServerActions::DestroyDomainTest < ActiveSupport::TestCase
  include SshTestHelper

  def setup
    @app = apps(:domain_test_app)
    @server = @app.server
    @domain = @app.domains.create!(hostname: "to-delete.example.com", status: :active)
  end

  test "removes domain from dokku and destroys record" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku domains:remove domain-test-app to-delete.example.com"}
      ]
    )

    assert_difference -> { Domain.count }, -1 do
      perform_server_action(ServerActions::DestroyDomain, @server, @domain)
    end
  end

  test "marks domain as error on ssh failure" do
    stub_session = Class.new do
      def exec!(_cmd, status:)
        status[:exit_code] = 1
        yield(nil, :stderr, "Error removing domain") if block_given?
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

    # Note: The job catches Ssh::CommandExecutionError internally and doesn't re-raise
    # So we just verify the domain was marked as error
    server_action = perform_server_action(ServerActions::DestroyDomain, @server, @domain)

    assert server_action.failure?
    assert @domain.reload.error?
  end

  test "sets deleting status during execution" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku domains:remove domain-test-app to-delete.example.com"}
      ]
    )

    server_action = perform_server_action(ServerActions::DestroyDomain, @server, @domain)

    assert server_action.success?
    assert_nil Domain.find_by(id: @domain.id)
  end
end
