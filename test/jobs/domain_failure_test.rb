require "test_helper"
require_relative "../../app/models/ssh/session"

class DomainFailureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "activation broadcast failure preserves the persisted active domain" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    domain.define_singleton_method(:active!) do
      super()
      run_callbacks(:commit)
    end
    domain.expects(:broadcast_replace_later_to).once.raises(IOError, "broadcast unavailable")
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::AddCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    assert domain.reload.active?
    assert action.reload.error?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
    assert_includes action.failure_message, "broadcast unavailable"
  end

  test "SSL enqueue failure preserves an already activated domain" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    domain.app.stubs(:deployed?).returns(true)
    domain.app.stubs(:all_domains_resolve_to_server?).returns(true)
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    ServerActions::EnableSsl.expects(:run_later!).with(domain.server, domain.app).raises(IOError, "queue unavailable")
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::AddCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    assert domain.reload.active?
    assert action.reload.error?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
    assert_includes action.failure_message, "queue unavailable"
  end

  test "deletion reconciliation rejection does not replace a command failure" do
    domain = domains(:domain_test_secondary)
    action = ServerActions::DestroyDomain.create!(server: domain.server, actionable: domain)
    domain.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(domain))
    mock_domain_command(domain, Dokku::Domains::RemoveCommand, exit_code: 1)

    result = begin
      action.run_now
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
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    domain.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(domain))
    mock_domain_command(domain, Dokku::Domains::AddCommand, exit_code: 1)

    result = begin
      action.run_now
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
    action = ServerActions::DestroyDomain.create!(server: domain.server, actionable: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with(Dokku::Domains::RemoveCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd, anything).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(IOError) { action.run_now }
    end

    assert Domain.exists?(domain.id)
    assert domain.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.size
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
    assert_includes action.failure_message, "connection lost"
  end

  test "connection failure reconciles a pending domain creation" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(Net::SSH::AuthenticationFailed) { action.run_now }
    end

    assert domain.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_includes action.failure_message, "authentication rejected"
  end

  test "successful creation retains SSL scheduling for a deployed app" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    domain.app.stubs(:deployed?).returns(true)
    domain.app.stubs(:all_domains_resolve_to_server?).returns(true)
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    mock_domain_command(domain, Dokku::Domains::AddCommand, exit_code: 0)

    assert_enqueued_jobs 1, only: RunServerActionJob do
      action.run_now
    end

    assert domain.reload.active?
    assert action.reload.success?
    ssl_action = ServerActions::EnableSsl.where(actionable: domain.app).sole
    assert_equal domain.server, ssl_action.server
    assert ssl_action.queued?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
  end

  test "successful deletion removes the domain only after the remote command" do
    domain = domains(:domain_test_secondary)
    action = ServerActions::DestroyDomain.create!(server: domain.server, actionable: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      assert Domain.exists?(domain.id)
      assert domain.reload.deleting?
      options[:status][:exit_code] = 0
      command == Dokku::Domains::RemoveCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    transport.expects(:loop).once
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) { action.run_now }

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
      action = action_class.create!(server: domain.server, actionable: domain)
      command_class = (action_class == ServerActions::CreateDomain) ? Dokku::Domains::AddCommand : Dokku::Domains::RemoveCommand
      mock_domain_command(domain, command_class, exit_code: 1)

      assert_no_enqueued_jobs(only: RunServerActionJob) { action.run_now }

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
    action = ServerActions::DestroyDomain.create!(server: domain.server, actionable: domain)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(Net::SSH::AuthenticationFailed) { action.run_now }

    assert Domain.exists?(domain.id)
    assert domain.reload.error?
    assert action.reload.error?
    assert action.finished_at
  end

  test "activation rollback reconciles using persisted state" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    original_touch = domain.app.method(:touch)
    domain.app.define_singleton_method(:touch) do |*args, **kwargs|
      if @activation_touch_failed
        original_touch.call(*args, **kwargs)
      else
        @activation_touch_failed = true
        raise IOError, "activation touch failed"
      end
    end
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::AddCommand.new(app: domain.app.dokku_id, domain: domain.hostname).cmd
    end
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    assert domain.reload.error?
    assert action.reload.error?
    assert_includes action.failure_message, "activation touch failed"
  end

  test "failed remote add does not preserve a preexisting active status" do
    domain = domains(:domain_test_secondary)
    assert domain.active?
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    mock_domain_command(domain, Dokku::Domains::AddCommand, exit_code: 1)

    action.run_now

    assert domain.reload.error?
    assert action.reload.failure?
  end

  test "creation reconciliation rejection preserves an unexpected SSH exception" do
    domain = domains(:domain_test_secondary)
    domain.pending!
    action = ServerActions::CreateDomain.create!(server: domain.server, actionable: domain)
    domain.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(domain))
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    assert action.reload.error?
    assert action.finished_at
    assert_includes action.failure_message, "connection lost"
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
