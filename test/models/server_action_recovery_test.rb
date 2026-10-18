require "test_helper"

class ServerActionRecoveryTest < ActiveSupport::TestCase
  # Recovery must read durable queue/claim markers after independent commits.
  self.use_transactional_tests = false

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "recovery", status: :active)
  end

  teardown do
    runs = ServerActionRun.where(resource_key: "app:#{@app.id}")
    tokens = runs.where.not(api_token_id: nil).pluck(:api_token_id)
    runs.destroy_all
    @app.destroy!
    ApiTokenAudit.where(api_token_id: tokens).delete_all
    ApiToken.where(id: tokens).delete_all
  end

  test "durable unsent obligation is dispatched after queue recovery and terminal invalid dispatch is visible" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app, dispatch: false)
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
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == "dokku ps:restart #{@app.dokku_id}"
    end
    transport.expects(:loop).raises(IOError, "private-bookkeeping")
    Net::SSH.expects(:start).yields(transport)
    assert_raises(IOError) { ServerAction::Runner.new(run).call }
    assert run.reload.remote_completed_at
    assert run.finalized_at
    assert @app.reload.active?
    assert_equal "succeeded", Api::V1::OperationResource.new(run).to_h.fetch("status")
    assert_nil Api::V1::OperationResource.new(run).to_h.fetch("error")
    run.update!(status: :running, finished_at: nil)
    ServerAction::Recovery.call
    assert run.reload.success?
    refute run.outcome_uncertain?
  end

  test "completion marker SQL failure keeps durable uncertainty despite dirty in memory evidence" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    connection = ServerActionRun.connection
    connection.execute(<<~SQL)
      CREATE FUNCTION public_operation_marker_unavailable() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.remote_completed_at IS NOT NULL AND OLD.remote_completed_at IS NULL THEN
          RAISE EXCEPTION 'test completion marker unavailable';
        END IF;
        RETURN NEW;
      END $$
    SQL
    connection.execute("CREATE TRIGGER public_operation_marker_unavailable BEFORE UPDATE ON server_action_runs FOR EACH ROW EXECUTE FUNCTION public_operation_marker_unavailable()")
    Server.any_instance.stubs(:ssh_session).yields(stub(commands: [], execute!: nil))
    assert_raises(ActiveRecord::StatementInvalid) { ServerAction::Runner.new(run).call }
    assert_nil run.reload.remote_completed_at
    assert run.error?
    assert run.outcome_uncertain?
    assert_equal "outcome_unknown", Api::V1::OperationResource.new(run).to_h.deep_symbolize_keys.dig(:error, :code)
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
  ensure
    connection&.execute("DROP TRIGGER IF EXISTS public_operation_marker_unavailable ON server_action_runs")
    connection&.execute("DROP FUNCTION IF EXISTS public_operation_marker_unavailable()")
  end

  test "revocation of a queued API operation prevents SSH" do
    token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write"])
    run = ServerAction::Accept.call(token: token, scope: "apps:write", endpoint: "restart", target: @app,
      request: {}, key: "queued-revocation", request_id: "request") { ServerAction::Enqueue.build(action: "apps.restart", target: @app) }
    token.update!(revoked_at: Time.current)
    Net::SSH.expects(:start).never
    assert_raises(ServerAction::Accept::Error) { ServerAction::Runner.new(run).call }
    assert run.reload.error?
    assert_equal "authorization_failed", run.public_error_code
  end

  test "unexpected interruption after starting execution retains app exclusion without replay" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    transport = mock("SSH transport")
    transport.expects(:exec!).raises(IOError, "private-disconnect-after-send")
    Net::SSH.expects(:start).yields(transport)
    assert_raises(IOError) { ServerAction::Runner.new(run).call }
    assert run.reload.outcome_uncertain?
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
  end
end
