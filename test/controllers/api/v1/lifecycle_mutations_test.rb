require "test_helper"

class Api::V1::LifecycleMutationsTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @app = apps(:domain_test_app)
    @app.update!(deployed_at: Time.current)
    @app.server.update!(status: :active)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:read", "apps:write", "deployments:write", "operations:read"])
    @secret = @token.token
  end

  teardown do
    ServerActionLog.delete_all
    ApiTokenAudit.delete_all
    ApiToken.delete_all
  end

  test "restart is durable asynchronous correlated and identical retries precede the busy check" do
    Server.any_instance.expects(:ssh_session).never
    assert_difference "ServerActionRun.count", 1 do
      post restart_path, headers: auth("restart")
      assert_response :accepted
    end
    operation = json_response.fetch("operation")
    assert_equal "queued", operation.fetch("status")
    assert_equal "app.restart", operation.fetch("kind")
    assert_equal @app.id, operation.fetch("app_id")
    assert_equal response.headers["X-Request-ID"], operation.fetch("request_id")
    assert_equal "/api/v1/operations/#{operation.fetch("id")}", response.headers["Location"]
    assert_equal "2", response.headers["Retry-After"]
    run = ServerActionRun.find(operation.fetch("id"))
    assert run.enqueued_at || run.dispatch_pending_at
    assert_equal @token.id, run.api_token_id
    assert_equal @token.user_id, run.user_id
    assert_equal "api_v1", run.source
    assert_no_difference "ServerActionRun.count" do
      post restart_path, headers: auth("restart")
      assert_response :accepted
      assert_equal operation, json_response.fetch("operation")
      post restart_path, headers: auth("different")
      assert_response :conflict
      assert_equal "operation_conflict", json_response.dig("error", "code")
    end
  end

  test "delete keeps target until remote success and replays after destruction" do
    delete "/api/v1/apps/#{@app.id}", headers: auth("delete")
    assert_response :accepted
    operation = json_response.fetch("operation")
    run = ServerActionRun.find(operation.fetch("id"))
    assert @app.reload.persisted?
    assert_equal "app.delete", operation.fetch("kind")
    session = mock("ssh")
    session.stubs(:commands).returns([])
    session.expects(:execute!).with { |command| command.is_a?(Dokku::Apps::DestroyCommand) }
    Server.any_instance.stubs(:ssh_session).yields(session)
    RunServerActionJob.perform_now(run.id, run.resource_key)
    assert_nil App.find_by(id: @app.id)
    get "/api/v1/apps/#{@app.id}", headers: auth("read")
    assert_response :not_found
    get "/api/v1/operations/#{run.id}", headers: auth("read")
    assert_response :ok
    assert_equal "succeeded", json_response.dig("operation", "status")
    assert_no_difference "ServerActionRun.count" do
      delete "/api/v1/apps/#{@app.id}", headers: auth("delete")
      assert_response :accepted
      assert_equal run.id, json_response.dig("operation", "id")
      delete "/api/v1/apps/#{@app.id}", headers: auth("fresh-delete")
      assert_response :not_found
    end
  end

  test "restart rejects undeployed app and missing idempotency key without side effects" do
    @app.update!(deployed_at: nil)
    post restart_path, headers: auth("undeployed")
    assert_response :conflict
    assert_equal "operation_conflict", json_response.dig("error", "code")
    assert_no_difference "ServerActionRun.count" do
      post restart_path, headers: {"Authorization" => "Bearer #{@secret}"}
      assert_response :bad_request
    end
  end

  test "HTTP acceptance audit failure returns unavailable and rolls back while queue outage remains durable" do
    ServerActionRun.any_instance.stubs(:update!).raises(ActiveRecord::StatementInvalid, "private-database-sentinel")
    assert_no_difference "ServerActionRun.count" do
      post restart_path, headers: auth("audit-failed")
      assert_response :service_unavailable
      assert_equal "unavailable", json_response.dig("error", "code")
      refute_includes response.body, "private-database-sentinel"
    end
    ServerActionRun.any_instance.unstub(:update!)
    RunServerActionJob.any_instance.stubs(:enqueue).raises(ActiveJob::EnqueueError, "private-queue-sentinel")
    post restart_path, headers: auth("queue-failed")
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    assert run.dispatch_pending_at
    assert run.scheduling_failed_at
    refute_includes response.body, "private-queue-sentinel"
    RunServerActionJob.any_instance.unstub(:enqueue)
    ServerAction::Recovery.call
    assert run.reload.enqueued_at
    assert_nil run.dispatch_pending_at
  end

  private

  def restart_path = "/api/v1/apps/#{@app.id}/restarts"
  def auth(key) = {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key}
end
