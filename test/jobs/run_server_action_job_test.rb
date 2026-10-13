require "test_helper"
require_relative "../../app/models/ssh/session"

class RunServerActionJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "connection failure reconciles a pending app" do
    app = apps(:smol_roda)
    app.pending!
    action = create_server_action_run("apps.create", server: app.server, target: app)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert app.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
  end

  test "production failures propagate without scheduling a mutation retry" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    Rails.env.stubs(:local?).returns(false)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert action.reload.error?
    assert action.finished_at
  end

  test "unexpected SSH failure preserves completed and interrupted commands" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Apps::CreateCommand.new(app: app.dokku_id).cmd
    end.yields(nil, :stdout, "created app\n")
    transport.expects(:exec!).with(Dokku::Domains::ReportCommand.new(app: app.dokku_id).cmd, anything).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    action.reload
    assert action.log, "partial SSH logs must survive an exception"
    assert_equal 2, action.log.ssh_commands.size
    assert_equal "created app\n", action.log.ssh_commands.first.fetch("output").first.fetch("data")
    assert_nil action.log.ssh_commands.last.fetch("exit_code")
    assert_match(/Server action failed/, action.failure_message)
    assert app.reload.error?
  end

  test "failed restart is not reported as an active app" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "restart failed"}
      ])

    perform_server_action_run(action)

    assert app.reload.error?
    assert action.reload.failure?
    assert_equal "restart failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end

  test "connection failure reconciles an app already marked restarting" do
    app = apps(:smol_roda)
    app.restarting!
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert app.reload.error?
  end

  test "reconciliation errors do not mask the original failure or strand the action" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    ServerAction::Registry::ACTIONS.fetch(action.action_key).any_instance.stubs(:failed!).raises(ActiveRecord::RecordInvalid.new(app))
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
  end

  test "failed log persistence does not prevent failure reconciliation" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    log_error = ActiveRecord::RecordInvalid.new(action)
    ssh_error = IOError.new("connection lost")
    ServerAction::LogPersistence.any_instance.stubs(:persist).raises(log_error)
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(ssh_error)
    Net::SSH.expects(:start).once.yields(transport)
    Honeybadger.stubs(:notify)
    Honeybadger.expects(:notify).with { |error, options| error.message.include?("log persistence") && !error.message.include?("connection lost") }.once
    Honeybadger.expects(:notify).with { |error, options| error.message.include?("execution") && !error.message.include?("connection lost") }.once

    assert_same ssh_error, assert_raises(IOError) { ServerAction::Runner.new(action).call }

    assert app.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
  end

  test "successful restart preserves the successful job lifecycle" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd, exit_code: 0, stdout: "restarted"}
      ])

    assert_equal action, perform_server_action_run(action)

    assert app.reload.active?
    assert action.reload.success?
    assert action.running_at
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal "restarted", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end

  test "unexpected SSH failure updates an existing log without duplicating it" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    log = action.create_log!(ssh_commands: [])
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_difference "ServerActionLog.count" do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert_equal log.id, action.reload.log.id
    assert_equal 1, log.reload.ssh_commands.size
    assert_nil log.ssh_commands.first.fetch("exit_code")
    assert app.reload.error?
    assert action.error?
  end

  test "restart reconciliation failure preserves the original SSH exception" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    App.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(app))
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "restart connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "Solid Queue retains a failed execution without automatically replaying the action" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.create", server: app.server, target: app)
    worker = SolidQueue::Process.register(kind: "Worker", name: "hardening-action-test", pid: Process.pid)
    queued = SolidQueue::Job.enqueue(RunServerActionJob.new(action.id, action.resource_key).set(queue: "hardening-action-test"))
    execution = SolidQueue::ReadyExecution.claim(["hardening-action-test"], 1, worker.id).sole
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_difference "SolidQueue::Job.count" do
      assert_raises(RunServerActionJob::ExecutionError) { execution.perform }
    end

    assert queued.reload.failed_execution
    assert_nil queued.finished_at
    assert_not SolidQueue::ReadyExecution.exists?(job: queued)
    assert_not SolidQueue::ScheduledExecution.exists?(job: queued)
    assert_not SolidQueue::ClaimedExecution.exists?(job: queued)
    assert action.reload.error?
    assert app.reload.error?
  end

  test "command failure remains terminal when reconciliation is rejected" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    ServerAction::Registry::ACTIONS.fetch(action.action_key).any_instance.stubs(:failed!).raises(ActiveRecord::RecordInvalid.new(app))
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "restart failed"}
      ])

    assert_no_enqueued_jobs(only: RunServerActionJob) { perform_server_action_run(action) }

    assert action.reload.failure?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_equal "restart failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end
end
