require "test_helper"
require_relative "../../app/models/ssh/session"

class DomainFailureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "activation broadcast failure preserves the persisted active domain" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    ServerActions::CreateDomain.any_instance.stubs(:on_logs_persisted).raises(IOError, "broadcast unavailable")
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::AddCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    transport.expects(:loop).at_least_once
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert domain.reload.active?
    assert action.reload.error?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
    assert_match(/Server action failed/, action.failure_message)
  end

  test "SSL enqueue failure preserves an already activated domain" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    App.any_instance.stubs(:deployed?).returns(true)
    App.any_instance.stubs(:all_domains_resolve_to_server?).returns(true)
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    ServerAction::Enqueue.expects(:call).with(has_entries(action: ServerActions::EnableSsl, target: domain.app)).raises(IOError, "queue unavailable")
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::AddCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert domain.reload.active?
    assert action.reload.error?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
    assert_match(/Server action failed/, action.failure_message)
  end

  test "deletion reconciliation rejection does not replace a command failure" do
    domain = domains(:domain_test_secondary)
    action = create_server_action_run(ServerActions::DestroyDomain, server: domain.server, target: domain)
    Domain.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(domain))
    mock_domain_command(domain, Dokku::Domains::RemoveCommand, exit_code: 1)

    result = begin
      perform_server_action_run(action)
    rescue => error
      error
    end

    assert_equal action, result
    assert action.reload.failure?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_nil action.failure_message
    assert Domain.exists?(domain.id)
    assert domain.reload.deleting?
  end

  test "creation reconciliation rejection does not replace a command failure" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    Domain.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(domain))
    mock_domain_command(domain, Dokku::Domains::AddCommand, exit_code: 1)

    result = begin
      perform_server_action_run(action)
    rescue => error
      error
    end

    assert_equal action, result
    assert action.reload.failure?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_nil action.failure_message
    assert domain.reload.pending?
  end

  test "interrupted domain deletion preserves the record with an error status" do
    domain = domains(:domain_test_secondary)
    action = create_server_action_run(ServerActions::DestroyDomain, server: domain.server, target: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with(Dokku::Domains::RemoveCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd, anything).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert Domain.exists?(domain.id)
    assert domain.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.size
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
    assert_match(/Server action failed/, action.failure_message)
  end

  test "connection failure reconciles a pending domain creation" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert domain.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
  end

  test "successful creation retains SSL scheduling for a deployed app" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    App.any_instance.stubs(:deployed?).returns(true)
    App.any_instance.stubs(:all_domains_resolve_to_server?).returns(true)
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    mock_domain_command(domain, Dokku::Domains::AddCommand, exit_code: 0)

    assert_enqueued_jobs 1, only: RunServerActionJob do
      perform_server_action_run(action)
    end

    assert domain.reload.active?
    assert action.reload.success?
    ssl_action = ServerActionRun.where(action_key: "apps.enable_ssl").where(target: domain.app).sole
    assert_equal domain.server, ssl_action.server
    assert ssl_action.queued?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
  end

  test "successful deletion removes the domain only after the remote command" do
    domain = domains(:domain_test_secondary)
    action = create_server_action_run(ServerActions::DestroyDomain, server: domain.server, target: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      assert Domain.exists?(domain.id)
      assert domain.reload.deleting?
      options[:status][:exit_code] = 0
      command == Dokku::Domains::RemoveCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    transport.expects(:loop).once
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) { perform_server_action_run(action) }

    assert_not Domain.exists?(domain.id)
    assert action.reload.success?
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
  end

  [ServerActions::CreateDomain, ServerActions::DestroyDomain].each do |action_class|
    test "ordinary command failure reconciles #{action_class.name}" do
      domain = domains(:domain_test_secondary)
      domain.pending! if action_class == ServerActions::CreateDomain
      action = create_server_action_run(action_class, server: domain.server, target: domain)
      command_class = (action_class == ServerActions::CreateDomain) ? Dokku::Domains::AddCommand : Dokku::Domains::RemoveCommand
      mock_domain_command(domain, command_class, exit_code: 1)

      assert_no_enqueued_jobs(only: RunServerActionJob) { perform_server_action_run(action) }

      assert domain.reload.error?
      assert action.reload.failure?
      assert action.finished_at
      assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
      assert_equal "domain command failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
    end
  end

  test "connection failure preserves a domain queued for deletion" do
    domain = domains(:domain_test_secondary)
    domain.deleting!
    action = create_server_action_run(ServerActions::DestroyDomain, server: domain.server, target: domain)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert Domain.exists?(domain.id)
    assert domain.reload.error?
    assert action.reload.error?
    assert action.finished_at
  end

  test "activation rollback reconciles using persisted state" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    fail_next_domain_update(Domain, domain.id, "active", "activation touch failed")
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::AddCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert domain.reload.error?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "failed remote add does not preserve a preexisting active status" do
    domain = domains(:domain_test_secondary)
    assert domain.active?
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    mock_domain_command(domain, Dokku::Domains::AddCommand, exit_code: 1)

    perform_server_action_run(action)

    assert domain.reload.error?
    assert action.reload.failure?
  end

  test "creation reconciliation rejection preserves an unexpected SSH exception" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    action = create_server_action_run(ServerActions::CreateDomain, server: domain.server, target: domain)
    Domain.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(domain))
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
    assert domain.reload.pending?
  end

  private

  def mock_domain_command(domain, command_class, exit_code:)
    mock_ssh_session(host: domain.server.public_ip, user: "watergun", port: domain.server.ssh_port,
      private_key: domain.server.ssh_key.private_key, commands: [
        {cmd: command_class.new(app: domain.app.dokku_id, domain: domain.hostname).cmd, exit_code:, stderr: exit_code.zero? ? nil : "domain command failed"}
      ])
  end
end
