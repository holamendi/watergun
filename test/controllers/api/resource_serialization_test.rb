require "test_helper"

class Api::ResourceSerializationTest < ActionDispatch::IntegrationTest
  setup do
    @app = apps(:domain_test_app)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), name: "serializer", scopes: ["apps:read", "operations:read"])
    @secret = @token.token
    @headers = {"Authorization" => "Bearer #{@secret}"}
  end

  test "project collection uses the Alba resource with exact fields UTC dates and empty root" do
    Project.any_instance.expects(:serializable_hash).never
    get "/api/v1/projects", headers: @headers
    assert_response :ok
    assert_equal ["projects"], json_response.keys
    json_response.fetch("projects").each do |row|
      project = Project.find(row.fetch("id"))
      assert_equal %w[created_at id name server_id updated_at], row.keys.sort
      assert_equal project.created_at.utc.iso8601, row.fetch("created_at")
      assert_equal project.updated_at.utc.iso8601, row.fetch("updated_at")
    end
    assert Api::V1::ProjectResource < Api::ApplicationResource
    assert_equal json_response, JSON.parse(Api::V1::ProjectResource.new(Project.kept.order(:id)).serialize)
    get "/api/v1/projects?page=9999", headers: @headers
    assert_equal({"projects" => []}, json_response)
  end

  test "operation resource maps every status and kind with exact fields safe errors and microsecond dates" do
    ServerActionRun.any_instance.expects(:public_operation).never
    ServerActionRun.any_instance.expects(:serializable_hash).never
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app, payload: {secret: "payload-sentinel"})
    at = Time.utc(2026, 10, 17, 12, 34, 56, 123456)
    run.update!(request_id: "original-identity", operation_app_id: @app.id,
      created_at: at, failure_message: "diagnostic-sentinel", idempotency_digest: "key-sentinel", request_fingerprint: "fingerprint-sentinel")
    cases = [
      ["queued", nil, nil, nil, nil, "queued", nil],
      ["running", at, nil, nil, nil, "running", nil],
      ["success", at, at, nil, nil, "succeeded", nil],
      ["error", at, at, at, "outcome_unknown", "succeeded", nil],
      ["failure", at, at, nil, "remote_failed", "failed", "remote_failed"],
      ["cancelled", nil, at, nil, "authorization_failed", "failed", "authorization_failed"],
      ["error", at, at, nil, "dispatch_failed", "failed", "dispatch_failed"],
      ["error", at, at, nil, "unsafe-error-sentinel", "failed", "outcome_unknown"],
      ["error", at, at, nil, nil, "failed", "remote_failed"]
    ]
    cases.each do |status, started, finished, completed, code, expected_status, expected_code|
      run.update!(status: status, running_at: started, finished_at: finished, remote_completed_at: completed, public_error_code: code)
      get "/api/v1/operations/#{run.id}", headers: @headers
      assert_response :ok
      assert_equal ["operation"], json_response.keys
      row = json_response.fetch("operation")
      assert_equal %w[app_id created_at deployment_id error finished_at id kind request_id started_at status], row.keys.sort
      assert_equal expected_status, row.fetch("status")
      assert_equal "original-identity", row.fetch("request_id")
      assert_equal at.iso8601(6), row.fetch("created_at")
      assert_equal [started&.iso8601(6), finished&.iso8601(6)], row.values_at("started_at", "finished_at")
      expected_error = expected_code ? {"code" => expected_code, "message" => expected_code.humanize} : nil
      assert_equal [expected_error], [row.fetch("error")]
      refute_match(/sentinel|payload|token|fingerprint|digest|failure_message|target_type|server_id|user_id|account_id/, response.body)
    end
    ServerActionRun::PUBLIC_KINDS.each do |action, kind|
      run.update!(action_key: action, operation_deployment_id: 123)
      get "/api/v1/operations/#{run.id}", headers: @headers
      assert_response :ok
      assert_equal kind, json_response.dig("operation", "kind")
      assert_equal 123, json_response.dig("operation", "deployment_id")
    end
    assert Api::V1::OperationResource < Api::ApplicationResource
    assert_equal json_response, JSON.parse(Api::V1::OperationResource.new(run).serialize)
  end

  test "token metadata uses Alba for collections details issuance rotation revocation and legacy claim" do
    ApiToken.any_instance.expects(:public_metadata).never
    ApiToken.any_instance.expects(:serializable_hash).never
    sign_in users(:bobby)
    get "/account/api_tokens", as: :json
    assert_response :ok
    assert_equal ["api_tokens"], json_response.keys
    assert_token_metadata json_response.fetch("api_tokens").sole
    get "/account/api_tokens/#{@token.id}", as: :json
    assert_response :ok
    assert_token_metadata json_response.fetch("api_token")
    post "/account/api_tokens", params: {api_token: {name: "issued", scopes: ["apps:read"]}}, as: :json
    assert_response :created
    assert_equal %w[api_token secret], json_response.keys.sort
    assert_token_metadata json_response.fetch("api_token")
    issued_secret = json_response.fetch("secret")
    id = json_response.dig("api_token", "id")
    post "/account/api_tokens/#{id}/rotate", params: {api_token: {name: "rotated", scopes: ["apps:read"]}}, as: :json
    assert_response :created
    assert_equal %w[api_token secret], json_response.keys.sort
    assert_token_metadata json_response.fetch("api_token")
    refute_includes response.body, issued_secret
    delete "/account/api_tokens/#{json_response.dig("api_token", "id")}", as: :json
    assert_response :ok
    assert_equal ["api_token"], json_response.keys
    assert_token_metadata json_response.fetch("api_token")
    assert json_response.dig("api_token", "revoked_at")
    legacy = ApiToken.create!(account: @app.account, name: "legacy")
    post "/account/api_tokens/claim", params: {token: legacy.token}, as: :json
    assert_response :ok
    assert_equal ["api_token"], json_response.keys
    assert_token_metadata json_response.fetch("api_token")
    refute_includes response.body, legacy.token
    assert Api::ApiTokenResource < Api::ApplicationResource
    assert_equal json_response, JSON.parse(Api::ApiTokenResource.new(legacy.reload).serialize)
  end

  private

  def assert_token_metadata(row)
    assert_equal %w[created_at expires_at id last_used_at name read_only revoked_at scopes], row.keys.sort
    token = ApiToken.find(row.fetch("id"))
    %w[created_at expires_at last_used_at revoked_at].each do |field|
      assert_equal [token.public_send(field)&.utc&.iso8601], [row.fetch(field)]
    end
    refute_match(/token_digest|account_id|user_id|replacement_id/, row.to_json)
    refute_includes row.to_json, token.token_digest
    refute_includes row.to_json, @secret
  end
end
