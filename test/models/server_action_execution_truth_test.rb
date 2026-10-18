require "test_helper"

class ServerActionExecutionTruthTest < ActiveSupport::TestCase
  include SshTestHelper

  setup { @app = apps(:domain_test_app) }

  test "authentication rejected before an SSH session does not freeze future app work" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    Net::SSH.expects(:start).raises(Net::SSH::AuthenticationFailed, "test-only rejected credentials")

    assert_raises(Net::SSH::AuthenticationFailed) { ServerAction::Runner.new(run).call }

    assert run.reload.error?
    refute run.outcome_uncertain?, "no SSH block ran and no remote command could have been sent"
    assert_nil run.remote_completed_at
    assert_equal "execution_failed", run.public_error_code
    replacement = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    assert replacement.persisted?
    refute_equal run.id, replacement.id
  end

  test "required domain discovery failure is repair required rather than successful creation" do
    run = ServerAction::Enqueue.call(action: "apps.create", target: @app)
    mock_ssh_session(host: @app.server.public_ip, user: SshKey::USER, port: @app.server.ssh_port,
      private_key: @app.server.ssh_key.private_key, ordered: true,
      commands: [{cmd: "dokku apps:create #{@app.dokku_id}"},
        {cmd: "dokku domains:report #{@app.dokku_id}", exit_code: 1, stderr: "test report unavailable"}])

    ServerAction::Runner.new(run).call

    assert run.reload.remote_completed_at
    assert @app.reload.error?
    resource = Api::V1::OperationResource.new(run).to_h
    assert_equal "failed", resource.fetch("status")
    assert_equal "repair_required", resource.dig("error", :code)
    refute run.outcome_uncertain?, "primary remote completion is known, but required local setup is not"
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.destroy", target: @app) }
  end

  test "optional restart toast failure does not require domain repair" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app, user: users(:bobby))
    mock_ssh_session(host: @app.server.public_ip, user: SshKey::USER, port: @app.server.ssh_port,
      private_key: @app.server.ssh_key.private_key, commands: [{cmd: "dokku ps:restart #{@app.dokku_id}"}])
    Toast.expects(:append_to_user).raises(IOError, "test-only notification unavailable")

    ServerAction::Runner.new(run).call

    assert_equal "succeeded", run.reload.public_status
    assert_nil Api::V1::OperationResource.new(run).to_h.fetch("error")
    assert @app.reload.active?
  end
end
