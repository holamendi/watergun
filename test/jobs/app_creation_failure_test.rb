require "test_helper"
require_relative "../../app/models/ssh/session"

class AppCreationFailureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "activation broadcast failure preserves the persisted active app" do
    app = apps(:smol_roda)
    ServerActions::CreateApp.any_instance.stubs(:on_logs_persisted).raises(IOError, "broadcast unavailable")
    action = create_server_action_run("apps.create", server: app.server, target: app)
    successful_creation_transport(app).expects(:loop).at_least_once

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert app.reload.active?, action.reload.failure_message
    assert action.error?
    assert_equal [0, 0], action.log.ssh_commands.map { it.fetch("exit_code") }
    assert_match(/Server action failed/, action.failure_message)
  end

  test "rejected creation reconciliation does not replace the command failure" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    App.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(app))
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Apps::CreateCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "creation rejected"}
      ])

    failure = nil
    begin
      perform_server_action_run(action)
    rescue => error
      failure = error
    end

    assert_nil failure, "command failure should remain terminal, not become #{failure.class}"
    assert action.reload.failure?
    assert action.finished_at
    assert_equal "creation rejected", action.log.ssh_commands.first.fetch("output").first.fetch("data")
    assert app.reload.pending?
  end

  test "activation rollback reconciles the persisted app state" do
    app = apps(:smol_roda)
    fail_next_domain_update(App, app.id, "active", "activation touch failed")
    action = create_server_action_run("apps.create", server: app.server, target: app)
    successful_creation_transport(app)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert app.reload.error?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "failed remote creation reconciles a previously active app" do
    app = apps(:domain_test_app)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Apps::CreateCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "creation rejected"}
      ])

    assert_no_enqueued_jobs(only: RunServerActionJob) { perform_server_action_run(action) }

    assert app.reload.error?
    assert action.reload.failure?
    assert action.finished_at
  end

  test "domain report command failure reconciles the partially created app" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, ordered: true, commands: [
        {cmd: Dokku::Apps::CreateCommand.new(app: app.dokku_id).cmd, exit_code: 0},
        {cmd: Dokku::Domains::ReportCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "report failed"}
      ])

    perform_server_action_run(action)

    assert app.reload.error?
    assert action.reload.failure?
    assert_equal [0, 1], action.log.ssh_commands.map { it.fetch("exit_code") }
    assert_nil action.failure_message
  end

  test "unexpected SSH failure survives rejected reconciliation" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    App.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(app))
    transport = mock("SSH transport")
    failure = IOError.new("connection lost")
    transport.expects(:exec!).raises(failure)
    Net::SSH.expects(:start).once.yields(transport)

    assert_same failure, assert_raises(IOError) { ServerAction::Runner.new(action).call }

    assert app.reload.pending?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
  end

  test "SSH teardown failure preserves committed activation" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    transport = successful_creation_transport(app)
    transport.expects(:loop).once.raises(IOError, "teardown failed")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert app.reload.active?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "successful creation retains domains and service link scheduling" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    transport = successful_creation_transport(app)
    transport.expects(:loop).at_least_once

    assert_difference "app.domains.count", 1 do
      assert_enqueued_jobs app.project.services.kept.count, only: RunServerActionJob do
        assert_equal action, perform_server_action_run(action)
      end
    end

    assert app.reload.active?
    assert action.reload.success?
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal app.project.services.kept.count, app.service_links.count
    assert_equal [0, 0], action.log.ssh_commands.map { it.fetch("exit_code") }
  end

  private

  def successful_creation_transport(app)
    transport = mock("SSH transport")
    order = sequence("app creation commands")
    transport.expects(:exec!).in_sequence(order).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Apps::CreateCommand.new(app: app.dokku_id).cmd
    end
    transport.expects(:exec!).in_sequence(order).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Domains::ReportCommand.new(app: app.dokku_id).cmd
    end.yields(nil, :stdout, file_fixture("dokku/domains/report_command_output.txt").read)
    Net::SSH.expects(:start).once.yields(transport)
    transport
  end
end
