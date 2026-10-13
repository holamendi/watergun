require "test_helper"
require_relative "../../app/models/ssh/session"
require "turbo/broadcastable/test_helper"

class DeploymentFailureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper
  include Turbo::Broadcastable::TestHelper

  test "failure broadcasts the reconciled deployment status" do
    deployment = deployments(:pending_deployment)
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "deployment connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    streams = capture_turbo_stream_broadcasts deployment do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert_equal 2, streams.size
    assert_includes streams.last.to_s, "Error"
  end

  test "interrupted deployment leaves the app in error rather than active" do
    deployment = deployments(:pending_deployment)
    app = deployment.app
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "deployment connection lost")
    Net::SSH.expects(:start).once.yields(transport)

    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }
    end

    assert app.reload.error?
    assert deployment.reload.error?
    assert deployment.finished_at
    assert action.reload.error?
    assert_equal 1, action.log.ssh_commands.size
  end

  test "deployment reconciliation rejection preserves the original transport failure" do
    deployment = deployments(:pending_deployment)
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    Deployment.any_instance.stubs(:error!).raises(ActiveRecord::RecordInvalid.new(deployment))
    original = IOError.new("deployment connection lost")
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(original)
    Net::SSH.expects(:start).once.yields(transport)

    raised = assert_raises(StandardError) { ServerAction::Runner.new(action).call }

    assert_same original, raised
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
    assert deployment.app.reload.error?
  end

  test "failed deployment never attempts the successful app transition" do
    deployment = deployments(:pending_deployment)
    app = deployment.app
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    App.any_instance.expects(:active!).never
    original = IOError.new("deployment connection lost")
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(original)
    Net::SSH.expects(:start).once.yields(transport)

    assert_same original, assert_raises(IOError) { ServerAction::Runner.new(action).call }

    assert app.reload.error?
  end

  test "command exit failure is terminal without follow-up mutations" do
    deployment = deployments(:pending_deployment)
    app = deployment.app
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Git::AuthCommand.new(access_token: app.account.github_installation.access_token.token).cmd, exit_code: 0},
        {cmd: Dokku::Git::SyncCommand.new(app: app.dokku_id, repo: action.payload["repo"], sha: action.payload["sha"]).cmd, exit_code: 1, stderr: "git sync failed"}
      ], ordered: true)

    assert_no_enqueued_jobs(only: RunServerActionJob) { perform_server_action_run(action) }

    assert app.reload.error?
    assert deployment.reload.error?
    assert deployment.finished_at
    assert action.reload.failure?
    assert_equal 2, action.log.ssh_commands.size
    assert_equal "git sync failed", action.log.ssh_commands.last.fetch("output").first.fetch("data")
  end

  test "successful deployment retains app activation and environment refresh" do
    deployment = deployments(:pending_deployment)
    app = deployment.app
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    mock_ssh_session(host: app.server.public_ip, user: "watergun", port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key, commands: [
        {cmd: Dokku::Git::AuthCommand.new(access_token: app.account.github_installation.access_token.token).cmd},
        {cmd: Dokku::Git::SyncCommand.new(app: app.dokku_id, repo: action.payload["repo"], sha: action.payload["sha"]).cmd},
        {cmd: Dokku::Ps::RebuildCommand.new(app: app.dokku_id).cmd}
      ], ordered: true)

    assert_enqueued_jobs 1, only: RunServerActionJob do
      perform_server_action_run(action)
    end

    assert action.reload.success?
    assert deployment.reload.success?
    assert deployment.finished_at
    assert app.reload.active?
    assert app.deployed_at
    assert_equal 3, action.log.ssh_commands.size
    assert_equal app, ServerActionRun.where(action_key: "apps.pull_env").order(:id).last.target
  end

  test "environment refresh failure does not overwrite a completed deployment" do
    deployment = deployments(:pending_deployment)
    app = deployment.app
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    transport = mock("SSH transport")
    order = sequence("successful deployment commands")
    [
      Dokku::Git::AuthCommand.new(access_token: app.account.github_installation.access_token.token).cmd,
      Dokku::Git::SyncCommand.new(app: app.dokku_id, repo: action.payload["repo"], sha: action.payload["sha"]).cmd,
      Dokku::Ps::RebuildCommand.new(app: app.dokku_id).cmd
    ].each do |expected_command|
      transport.expects(:exec!).with do |command, options|
        options[:status][:exit_code] = 0
        command == expected_command
      end.in_sequence(order)
    end
    Net::SSH.expects(:start).once.yields(transport)
    ServerAction::Enqueue.expects(:call).with(has_entries(action: "apps.pull_env")).raises(ActiveJob::EnqueueError, "refresh enqueue failed")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert deployment.reload.success?
    assert app.reload.active?
    assert deployment.finished_at
    assert app.deployed_at
    assert action.reload.error?
    assert_match(/Server action failed/, action.failure_message)
  end

  test "rolled back deployment success is still reconciled after app touch fails" do
    deployment = deployments(:pending_deployment)
    app = deployment.app
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    transport = mock("SSH transport")
    order = sequence("deployment commands before failed success transaction")
    [
      Dokku::Git::AuthCommand.new(access_token: app.account.github_installation.access_token.token).cmd,
      Dokku::Git::SyncCommand.new(app: app.dokku_id, repo: action.payload["repo"], sha: action.payload["sha"]).cmd,
      Dokku::Ps::RebuildCommand.new(app: app.dokku_id).cmd
    ].each do |expected_command|
      transport.expects(:exec!).with do |command, options|
        options[:status][:exit_code] = 0
        command == expected_command
      end.in_sequence(order)
    end
    Net::SSH.expects(:start).once.yields(transport)
    App.any_instance.expects(:touch).with(:deployed_at).raises(IOError, "touch failed")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert deployment.reload.error?
    assert app.reload.error?
    assert action.reload.error?
  end

  test "connection failure finishes a pending deployment as error" do
    deployment = deployments(:pending_deployment)
    action = create_server_action_run("apps.deploy", server: deployment.server, target: deployment)
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed, "authentication rejected")

    assert_raises(RunServerActionJob::ExecutionError) { perform_server_action_run(action) }

    assert deployment.reload.error?
    assert deployment.finished_at
    assert action.reload.error?
    assert action.finished_at
  end
end
