require "test_helper"
require_relative "../../app/models/ssh/session"

class ServiceLinkFailureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "connection failure reconciles a pending service link" do
    link = create_link
    action = create_server_action_run("services.link", server: link.server, target: link)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert link.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_match(/Server action failed/, action.failure_message)
  end

  test "interrupted unlink preserves an errored service link" do
    link = create_link(status: :active)
    action = create_server_action_run("services.unlink", server: link.server, target: link)
    command = Dokku::Services::UnlinkCommand.new(plugin: link.service.service_type, service: link.service.dokku_id, app: link.app.dokku_id).cmd
    transport = mock("SSH transport")
    transport.expects(:exec!).with(command, anything).raises(IOError, "unlink connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_difference "ServiceLink.count" do
      assert_no_enqueued_jobs(only: RunServerActionJob) do
        assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
      end
    end

    assert link.reload.error?
    assert action.reload.error?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.size
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
  end

  test "link reconciliation rejection preserves the command failure" do
    link = create_link
    action = create_server_action_run("services.link", server: link.server, target: link)
    ServiceLink.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(link))

    assert_command_failure(action, link_command(link))
  end

  test "unlink reconciliation rejection preserves the command failure" do
    link = create_link(status: :active)
    action = create_server_action_run("services.unlink", server: link.server, target: link)
    ServiceLink.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(link))

    assert_command_failure(action, unlink_command(link))
    assert ServiceLink.exists?(link.id)
  end

  test "SSH teardown failure preserves committed link activation" do
    link = create_link
    action = create_server_action_run("services.link", server: link.server, target: link)
    transport = successful_transport(link_command(link))
    transport.expects(:loop).once.raises(IOError, "teardown failed")

    assert_enqueued_jobs 1, only: RunServerActionJob do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert link.reload.active?
    assert action.reload.error?
    assert_equal 0, action.log.ssh_commands.first.fetch("exit_code")
    assert_match(/Server action failed/, action.failure_message)
  end

  test "connection failure reconciles a queued unlink" do
    link = create_link(status: :deleting)
    action = create_server_action_run("services.unlink", server: link.server, target: link)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert link.reload.error?
    assert ServiceLink.exists?(link.id)
    assert action.reload.error?
  end

  test "ordinary command failures reconcile service links" do
    link = create_link
    ["services.link", "services.unlink"].each do |action_key|
      action = create_server_action_run(action_key, server: link.server, target: link)
      command = (action_key == "services.link") ? link_command(link) : unlink_command(link)

      assert_command_failure(action, command)

      assert link.reload.error?
      assert ServiceLink.exists?(link.id)
    end
  end

  test "unexpected link failure survives rejected reconciliation" do
    link = create_link
    action = create_server_action_run("services.link", server: link.server, target: link)
    ServiceLink.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(link))
    transport = mock("SSH transport")
    failure = IOError.new("connection lost")
    transport.expects(:exec!).with(link_command(link), anything).raises(failure)
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_same failure, assert_raises(IOError) { ServerAction::Runner.new(action).call }
    end

    assert link.reload.pending?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
    assert_nil action.log.ssh_commands.first.fetch("exit_code")
  end

  test "activation callback failure preserves the persisted active link" do
    link = create_link
    ServerActions::LinkService.any_instance.stubs(:on_logs_persisted).raises(IOError, "broadcast unavailable")
    action = create_server_action_run("services.link", server: link.server, target: link)
    successful_transport(link_command(link)).expects(:loop).at_least_once

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert link.reload.active?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "activation rollback reconciles the persisted link state" do
    link = create_link
    fail_next_domain_update(ServiceLink, link.id, "active", "activation touch failed")
    action = create_server_action_run("services.link", server: link.server, target: link)
    successful_transport(link_command(link))

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert link.reload.error?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "refresh enqueue exception reconciles a partially linked target" do
    link = create_link
    action = create_server_action_run("services.link", server: link.server, target: link)
    ServerAction::Enqueue.stubs(:call).with(has_entries(action: "apps.pull_env")).raises(IOError, "refresh enqueue failed")
    successful_transport(link_command(link))

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert link.reload.error?
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "failed remote link reconciles a previously active target" do
    link = create_link(status: :active)
    action = create_server_action_run("services.link", server: link.server, target: link)

    assert_command_failure(action, link_command(link))

    assert link.reload.error?
  end

  test "successful link retains activation and refresh scheduling" do
    link = create_link
    action = create_server_action_run("services.link", server: link.server, target: link)
    successful_transport(link_command(link)).expects(:loop).at_least_once

    assert_enqueued_jobs 1, only: RunServerActionJob do
      assert_equal action, perform_server_action_run(action)
    end

    assert link.reload.active?
    assert action.reload.success?
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal [link_command(link)], action.log.ssh_commands.map { it.fetch("cmd") }
    assert_equal link.app, ServerActionRun.where(action_key: "apps.pull_env").last.target
  end

  test "successful unlink removes the record and schedules refresh" do
    link = create_link(status: :active)
    action = create_server_action_run("services.unlink", server: link.server, target: link)
    command = unlink_command(link)
    successful_transport(command).expects(:loop).at_least_once

    assert_difference "ServiceLink.count", -1 do
      assert_enqueued_jobs 1, only: RunServerActionJob do
        assert_equal action, perform_server_action_run(action)
      end
    end

    assert_not ServiceLink.exists?(link.id)
    assert action.reload.success?
    assert action.finished_at
    assert_equal [command], action.log.ssh_commands.map { it.fetch("cmd") }
    assert_equal link.app, ServerActionRun.where(action_key: "apps.pull_env").last.target
  end

  test "unlink teardown failure does not attempt reconciliation of a destroyed target" do
    link = create_link(status: :active)
    action = create_server_action_run("services.unlink", server: link.server, target: link)
    transport = successful_transport(unlink_command(link))
    transport.expects(:loop).once.raises(IOError, "teardown failed")
    ServiceLink.any_instance.expects(:error!).never

    assert_difference "ServiceLink.count", -1 do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert_not ServiceLink.exists?(link.id)
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  private

  def successful_transport(command)
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |actual, options|
      options[:status][:exit_code] = 0
      actual == command
    end
    Net::SSH.expects(:start).once.yields(transport)
    transport
  end

  def link_command(link)
    Dokku::Services::LinkCommand.new(plugin: link.service.service_type, service: link.service.dokku_id, app: link.app.dokku_id, env_name: link.env_variable.name).cmd
  end

  def unlink_command(link)
    Dokku::Services::UnlinkCommand.new(plugin: link.service.service_type, service: link.service.dokku_id, app: link.app.dokku_id).cmd
  end

  def assert_command_failure(action, command)
    server = action.server
    mock_ssh_session(host: server.public_ip, user: "watergun", port: server.ssh_port,
      private_key: server.ssh_key.private_key, commands: [{cmd: command, exit_code: 1, stderr: "remote command failed"}])

    failure = nil
    assert_no_enqueued_jobs(only: RunServerActionJob) do
      perform_server_action_run(action)
    rescue => error
      failure = error
    end
    assert_nil failure, "original command failure replaced by #{failure.class}"
    assert action.reload.failure?
    assert action.finished_at
    assert_nil action.failure_message
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_equal "remote command failed", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end

  def create_link(status: :pending)
    app = apps(:smol_roda)
    service = services(:redis)
    env = app.env_variables.create!(name: "INTERNAL_REDIS_URL", value: "test-only", internal: true)
    ServiceLink.create!(service:, app:, env_variable: env, status:)
  end
end
