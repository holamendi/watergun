require "test_helper"

class ServerActionRecoveryTest < ActiveSupport::TestCase
  setup { @app = apps(:domain_test_app) }

  test "durable unsent obligation is dispatched after queue recovery and terminal invalid dispatch is visible" do
    run = Current.set(accepting_server_action: true) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
    assert run.reload.dispatch_pending_at
    ServerAction::Recovery.call
    assert run.reload.enqueued_at
    assert_nil run.dispatch_pending_at
    run.update!(enqueued_at: nil, dispatch_pending_at: Time.current)
    @app.update_columns(dokku_id: "changed-identifier")
    ServerAction::Recovery.call
    assert run.reload.error?
    assert_equal "dispatch_failed", run.public_error_code
  end

  test "stranded running work is failed as uncertain and never dispatched again" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    run.update!(status: :running, running_at: 1.minute.ago)
    RunServerActionJob.expects(:new).never
    Net::SSH.expects(:start).never
    ServerAction::Recovery.call
    assert run.reload.error?
    assert run.outcome_uncertain?
    assert_equal "outcome_unknown", run.public_error_code
    ServerAction::Recovery.call
    ServerAction::Runner.new(run).call
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.destroy", target: @app) }
  end

  test "known committed remote completion survives log and teardown bookkeeping failure" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    action = ServerActions::RestartApp.new(run)
    ServerAction::Registry.stubs(:build).returns(action)
    action.stubs(:execute!)
    action.stubs(:succeeded!)
    Server.any_instance.stubs(:ssh_session).yields(stub(commands: [])).raises(IOError, "private-bookkeeping")
    assert_raises(IOError) { ServerAction::Runner.new(run).call }
    assert run.reload.remote_completed_at
    assert_equal "succeeded", run.public_operation.fetch(:status)
    assert_nil run.public_operation.fetch(:error)
    run.update!(status: :running, finished_at: nil)
    ServerAction::Recovery.call
    assert run.reload.success?
    refute run.outcome_uncertain?
  end

  test "revocation of a queued API operation prevents SSH" do
    token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write"])
    run = ServerAction::Accept.call(token: token, scope: "apps:write", endpoint: "restart", target: @app,
      request: {}, key: "queued-revocation", request_id: "request") { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
    token.update!(revoked_at: Time.current)
    Net::SSH.expects(:start).never
    assert_raises(ServerAction::Accept::Error) { ServerAction::Runner.new(run).call }
    assert run.reload.error?
    assert_equal "authorization_failed", run.public_error_code
  end

  test "unexpected interruption after starting execution retains app exclusion without replay" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    Server.any_instance.stubs(:ssh_session).raises(IOError, "private-disconnect")
    assert_raises(IOError) { ServerAction::Runner.new(run).call }
    assert run.reload.outcome_uncertain?
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
  end
end
