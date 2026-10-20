require "test_helper"

# Ensure Ssh::CommandExecutionError is loaded (defined in session.rb)

class ServerActions::CreateDomainTest < ActiveSupport::TestCase
  include SshTestHelper
  include ServerActionTestHelper

  def setup
    @app = apps(:domain_test_app)
    @server = @app.server
    @domain = @app.domains.create!(hostname: "newdomain.example.com", status: :pending)
  end

  test "adds domain to dokku and marks as active" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku domains:add domain-test-app newdomain.example.com"}
      ]
    )

    server_action = ServerActions::CreateDomain.run_now!(@server, @domain)

    assert server_action.success?
    assert @domain.reload.active?
  end

  test "marks domain as error on ssh failure" do
    stub_session = Class.new do
      def exec!(_cmd, status:)
        status[:exit_code] = 1
        yield(nil, :stderr, "Error adding domain") if block_given?
      end

      def loop
      end
    end.new

    Net::SSH.expects(:start)
      .with(@server.public_ip, SshKey::USER, ssh_connection_options(port: @server.ssh_port, private_key: @server.ssh_key.private_key))
      .yields(stub_session)

    # Note: The job catches Ssh::CommandExecutionError internally and doesn't re-raise
    # So we just verify the domain was marked as error
    server_action = ServerActions::CreateDomain.run_now!(@server, @domain)

    assert server_action.failure?
    assert @domain.reload.error?
  end

  test "schedules enable ssl when app is deployed and all domains resolve" do
    @app.update!(deployed_at: Time.current)
    @app.stubs(:all_domains_resolve_to_server?).returns(true)

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku domains:add domain-test-app newdomain.example.com"}
      ]
    )

    ServerActions::CreateDomain.run_now!(@server, @domain)

    assert_server_action_scheduled(
      ServerActions::EnableSsl,
      server: @server,
      actionable: @app
    )
  end

  test "does not schedule enable ssl when app is not deployed" do
    @app.update!(deployed_at: nil)

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku domains:add domain-test-app newdomain.example.com"}
      ]
    )

    ServerActions::CreateDomain.run_now!(@server, @domain)

    assert_nil ServerAction.find_by(type: "ServerActions::EnableSsl", actionable: @app)
  end
end
