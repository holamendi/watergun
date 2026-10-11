require "test_helper"
require_relative "../../app/models/ssh/session"

class RunServerActionJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "connection failure reconciles a pending app" do
    app = apps(:smol_roda)
    app.pending!
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(Net::SSH::AuthenticationFailed) { action.run_now }

    assert app.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_includes action.failure_message, "authentication rejected"
  end

  test "production failures propagate without scheduling a mutation retry" do
    app = apps(:smol_roda)
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)
    Rails.env.stubs(:local?).returns(false)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(Net::SSH::AuthenticationFailed) { action.run_now }
    end

    assert action.reload.error?
    assert action.finished_at
  end

  test "unexpected SSH failure preserves completed and interrupted commands" do
    app = apps(:smol_roda)
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == Dokku::Apps::CreateCommand.new(app: app.dokku_id).cmd
    end.yields(nil, :stdout, "created app\n")
    transport.expects(:exec!).with(Dokku::Domains::ReportCommand.new(app: app.dokku_id).cmd, anything).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    action.reload
    assert action.log, "partial SSH logs must survive an exception"
    assert_equal 2, action.log.ssh_commands.size
    assert_equal "created app\n", action.log.ssh_commands.first.fetch("output").first.fetch("data")
    assert_nil action.log.ssh_commands.last.fetch("exit_code")
    assert_includes action.failure_message, "connection lost"
    assert app.reload.error?
  end

  test "failed restart is not reported as an active app" do
    app = apps(:smol_roda)
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "restart failed"}
      ])

    action.run_now

    assert app.reload.error?
    assert action.reload.failure?
    assert_equal "restart failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end

  test "connection failure reconciles an app already marked restarting" do
    app = apps(:smol_roda)
    app.restarting!
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed)

    assert_raises(Net::SSH::AuthenticationFailed) { action.run_now }

    assert app.reload.error?
  end

  test "reconciliation errors do not mask the original failure or strand the action" do
    app = apps(:smol_roda)
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)
    action.stubs(:on_failure).raises(ActiveRecord::RecordInvalid.new(app))
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(Net::SSH::AuthenticationFailed) { action.run_now }

    assert action.reload.error?
    assert action.finished_at
    assert_includes action.failure_message, "authentication rejected"
  end

  test "failed log persistence does not prevent failure reconciliation" do
    app = apps(:smol_roda)
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)
    action.stubs(:create_log!).raises(ActiveRecord::RecordInvalid.new(action))
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    assert app.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_includes action.failure_message, "connection lost"
  end

  test "successful restart preserves the successful job lifecycle" do
    app = apps(:smol_roda)
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd, exit_code: 0, stdout: "restarted"}
      ])

    assert_equal action, action.run_now

    assert app.reload.active?
    assert action.reload.success?
    assert action.running_at
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal "restarted", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end

  test "unexpected SSH failure updates an existing log without duplicating it" do
    app = apps(:smol_roda)
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)
    log = action.create_log!(ssh_commands: [])
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_difference "ServerActionLog.count" do
      assert_raises(IOError) { action.run_now }
    end

    assert_equal log.id, action.reload.log.id
    assert_equal 1, log.reload.ssh_commands.size
    assert_nil log.ssh_commands.first.fetch("exit_code")
    assert app.reload.error?
    assert action.error?
  end

  test "restart reconciliation failure preserves the original SSH exception" do
    app = apps(:smol_roda)
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)
    app.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(app))
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "restart connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_raises(IOError) { action.run_now }

    assert action.reload.error?
    assert_includes action.failure_message, "restart connection lost"
  end

  test "Solid Queue retains a failed execution without automatically replaying the action" do
    app = apps(:smol_roda)
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)
    worker = SolidQueue::Process.register(kind: "Worker", name: "hardening-action-test", pid: Process.pid)
    queued = SolidQueue::Job.enqueue(RunServerActionJob.new(action).set(queue: "hardening-action-test"))
    execution = SolidQueue::ReadyExecution.claim(["hardening-action-test"], 1, worker.id).sole
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_difference "SolidQueue::Job.count" do
      assert_raises(Net::SSH::AuthenticationFailed) { execution.perform }
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
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)
    action.stubs(:on_failure).raises(ActiveRecord::RecordInvalid.new(app))
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd, exit_code: 1, stderr: "restart failed"}
      ])

    assert_no_enqueued_jobs(only: RunServerActionJob) { action.run_now }

    assert action.reload.failure?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_equal "restart failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end
end
