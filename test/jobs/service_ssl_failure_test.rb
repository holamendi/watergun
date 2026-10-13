require "test_helper"
require_relative "../../app/models/ssh/session"

class ServiceSslFailureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "unexpected restart failure reconciles a restarting service" do
    service = services(:redis)
    action = create_server_action_run(ServerActions::RestartService, server: service.server, target: service)
    transport = mock("SSH transport")
    transport.expects(:exec!).with(Dokku::Services::RestartCommand.new(plugin: service.service_type, service: service.dokku_id).cmd, anything).raises(IOError, "restart connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert service.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.size
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
  end

  test "unexpected deletion failure preserves an errored service" do
    service = services(:redis)
    action = create_server_action_run(ServerActions::DestroyService, server: service.server, target: service)
    transport = mock("SSH transport")
    transport.expects(:exec!).with(Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id).cmd, anything).raises(IOError, "deletion connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_difference "Service.count" do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert service.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.size
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
  end

  test "unexpected SSL failure restores enabling domains without reporting SSL success" do
    app = apps(:domain_test_app)
    action = create_server_action_run(ServerActions::EnableSsl, server: app.server, target: app)
    transport = mock("SSH transport")
    transport.expects(:exec!).with(Dokku::Letsencrypt::EnableCommand.new(app: app.dokku_id).cmd, anything).raises(IOError, "SSL connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    app.domains.each do |domain|
      assert domain.reload.active?
      assert_not domain.ssl_enabled?
    end
    assert action.reload.error?
    assert action.finished_at
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
  end

  test "creation reconciliation rejection preserves a command-exit failure" do
    service = services(:postgres)
    action = create_server_action_run(ServerActions::CreateService, server: service.server, target: service)
    Service.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(service))

    assert_command_failure_preserved(action, Dokku::Plugin::ListCommand.new.cmd)
  end

  test "restart reconciliation rejection preserves a command-exit failure" do
    service = services(:redis)
    action = create_server_action_run(ServerActions::RestartService, server: service.server, target: service)
    Service.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(service))

    assert_command_failure_preserved(action, Dokku::Services::RestartCommand.new(plugin: service.service_type, service: service.dokku_id).cmd)
  end

  test "deletion reconciliation rejection preserves a command-exit failure" do
    service = services(:redis)
    action = create_server_action_run(ServerActions::DestroyService, server: service.server, target: service)
    Service.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(service))

    assert_command_failure_preserved(action, Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id).cmd)
    assert Service.exists?(service.id)
  end

  test "SSL reconciliation rejection preserves a command-exit failure" do
    app = apps(:domain_test_app)
    action = create_server_action_run(ServerActions::EnableSsl, server: app.server, target: app)
    Domain.any_instance.stubs(:active!).raises(ActiveRecord::RecordInvalid.new(domains(:domain_test_default)))

    assert_command_failure_preserved(action, Dokku::Letsencrypt::EnableCommand.new(app: app.dokku_id).cmd)
    assert_not app.domains.exists?(ssl_enabled: true)
  end

  test "connection failure reconciles a pending service creation" do
    service = services(:postgres)
    action = create_server_action_run(ServerActions::CreateService, server: service.server, target: service)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert service.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
  end

  test "connection failures reconcile queued service restart and deletion" do
    [ServerActions::RestartService, ServerActions::DestroyService].each do |klass|
      service = services(:redis)
      service.update!(status: (klass == ServerActions::RestartService) ? :restarting : :deleting)
      action = create_server_action_run(klass, server: service.server, target: service)
      Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed)

      assert_no_enqueued_jobs(only: RunServerActionJob) do
        assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
      end

      assert service.reload.error?
      assert Service.exists?(service.id)
      assert action.reload.error?
      assert action.finished_at
    end
  end

  test "SSL connection failure restores only enabling domains" do
    app = apps(:domain_test_app)
    enabling = domains(:domain_test_default)
    enabling.enabling_ssl!
    untouched = domains(:domain_test_secondary)
    untouched.update!(status: :error, ssl_enabled: true)
    action = create_server_action_run(ServerActions::EnableSsl, server: app.server, target: app)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert enabling.reload.active?
    assert_not enabling.ssl_enabled?
    assert untouched.reload.error?
    assert untouched.ssl_enabled?
    assert action.reload.error?
  end

  test "ordinary command failures reconcile service lifecycles" do
    [ServerActions::CreateService, ServerActions::RestartService, ServerActions::DestroyService].each do |klass|
      service = services(:redis)
      action = create_server_action_run(klass, server: service.server, target: service)
      command = case klass.name
      when "ServerActions::CreateService" then Dokku::Plugin::ListCommand.new
      when "ServerActions::RestartService" then Dokku::Services::RestartCommand.new(plugin: service.service_type, service: service.dokku_id)
      when "ServerActions::DestroyService" then Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id)
      end

      assert_command_failure_preserved(action, command.cmd)
      assert service.reload.error?
      assert Service.exists?(service.id)
    end
  end

  test "ordinary SSL command failure restores domains without enabling SSL" do
    app = apps(:domain_test_app)
    action = create_server_action_run(ServerActions::EnableSsl, server: app.server, target: app)

    assert_command_failure_preserved(action, Dokku::Letsencrypt::EnableCommand.new(app: app.dokku_id).cmd)

    app.domains.each do |domain|
      assert domain.reload.active?
      assert_not domain.ssl_enabled?
    end
  end

  test "SSL already enabled is a no op that preserves domain error status" do
    app = apps(:domain_test_app)
    app.domains.update_all(ssl_enabled: true, status: :error)
    action = create_server_action_run(ServerActions::EnableSsl, server: app.server, target: app)
    session = mock("no op SSL session")
    session.stubs(:commands).returns([])
    session.expects(:execute!).never
    Server.any_instance.stubs(:ssh_session).yields(session)

    perform_server_action_run(action)

    assert action.reload.success?
    app.domains.each do |domain|
      assert domain.reload.error?
      assert domain.ssl_enabled?
    end
  end

  test "successful SSL execution enables domains" do
    app = apps(:domain_test_app)
    action = create_server_action_run(ServerActions::EnableSsl, server: app.server, target: app)
    server = action.server
    command = Dokku::Letsencrypt::EnableCommand.new(app: app.dokku_id).cmd
    mock_ssh_session(host: server.public_ip, user: "watergun", port: server.ssh_port,
      private_key: server.ssh_key.private_key, commands: [{cmd: command, stdout: "SSL enabled"}])

    assert_equal action, perform_server_action_run(action)

    assert action.reload.success?
    assert_equal [command], action.log.ssh_commands.map { |entry| entry.fetch("cmd") }
    app.domains.each do |domain|
      assert domain.reload.active?
      assert domain.ssl_enabled?
    end
  end

  test "successful service deletion removes the record after remote success" do
    service = services(:redis)
    action = create_server_action_run(ServerActions::DestroyService, server: service.server, target: service)
    server = action.server
    command = Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id).cmd
    mock_ssh_session(host: server.public_ip, user: "watergun", port: server.ssh_port,
      private_key: server.ssh_key.private_key, commands: [{cmd: command, stdout: "service deleted"}])

    assert_difference "Service.count", -1 do
      assert_equal action, perform_server_action_run(action)
    end

    assert_not Service.exists?(service.id)
    assert action.reload.success?
    assert_equal [command], action.log.ssh_commands.map { |entry| entry.fetch("cmd") }
  end

  test "successful service creation preserves parsed data and link enqueue" do
    service = services(:postgres)
    action = create_server_action_run(ServerActions::CreateService, server: service.server, target: service)
    server = action.server
    commands = [
      {cmd: Dokku::Plugin::ListCommand.new.cmd, stdout: "postgres 1.0 enabled\n"},
      {cmd: Dokku::Services::CreateCommand.new(plugin: service.service_type, name: service.dokku_id).cmd},
      {cmd: Dokku::Services::InfoCommand.new(plugin: service.service_type, service: service.dokku_id).cmd, stdout: "Version: 18\nDsn: postgres://test-only\n"}
    ]
    mock_ssh_session(host: server.public_ip, user: "watergun", port: server.ssh_port,
      private_key: server.ssh_key.private_key, commands:, ordered: true)
    expected_app_ids = service.project.apps.kept.pluck(:id)

    assert_difference "ServiceLink.count", expected_app_ids.size do
      assert_equal action, perform_server_action_run(action)
    end

    assert service.reload.active?
    assert_equal "18", service.version
    assert_equal "postgres://test-only", service.dsn
    assert_equal expected_app_ids.sort, service.service_links.pluck(:app_id).sort
    assert_equal expected_app_ids.size, ServerActionRun.where(action_key: "services.link").where(target: service.service_links).count
    assert action.reload.success?
    assert_equal commands.map { |entry| entry.fetch(:cmd) }, action.log.ssh_commands.map { |entry| entry.fetch("cmd") }
  end

  private

  def assert_command_failure_preserved(action, command)
    server = action.server
    mock_ssh_session(host: server.public_ip, user: "watergun", port: server.ssh_port,
      private_key: server.ssh_key.private_key, commands: [
        {cmd: command, exit_code: 1, stderr: "remote command failed"}
      ])

    failure = nil
    assert_no_enqueued_jobs(only: RunServerActionJob) do
      perform_server_action_run(action)
    rescue => error
      failure = error
    end
    assert_nil failure, "reconciliation replaced the command failure with #{failure.class}"

    assert action.reload.failure?
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_equal "remote command failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end
end
