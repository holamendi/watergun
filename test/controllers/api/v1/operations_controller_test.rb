require "test_helper"
require "json_schemer"

class Api::V1::OperationsControllerTest < ActionDispatch::IntegrationTest
  include SshTestHelper

  # Setup uses real committed acceptance; the repair case executes its worker.
  self.use_transactional_tests = false

  teardown do
    ServerActionRun.where(id: @run.id).destroy_all
    App.find_by(id: @app.id)&.destroy!
    ApiTokenAudit.where(api_token_id: @token.id).delete_all
    @token.destroy!
  end

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "operations", status: :active)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write", "operations:read"])
    @secret = @token.token
    @run = ServerAction::Accept.call(token: @token, endpoint: "restart", target: @app, key: "http-op",
      request: {}, request_id: "original-request", scope: "apps:write") do
      ServerAction::Enqueue.build(action: "apps.restart", target: @app, payload: {note: "sentinel-operation-secret"})
    end
  end

  test "read operation is scoped safe correlated and carries explicit location and original request ID" do
    get "/api/v1/operations/#{@run.id}", headers: auth.merge("X-Request-ID" => "caller-controlled")
    assert_response :ok
    body = json_response.fetch("operation")
    assert_equal "queued", body.fetch("status")
    assert_equal @app.id, body.fetch("app_id")
    assert_equal "original-request", body.fetch("request_id")
    refute_equal "original-request", response.headers["X-Request-ID"]
    refute_equal "caller-controlled", response.headers["X-Request-ID"]
    assert_equal "/api/v1/operations/#{@run.id}", response.headers["Location"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "2", response.headers["Retry-After"]
    refute_match(/sentinel|payload|dokku|token|failure_message/, response.body)
    schema = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join("docs/api/openapi.yml"), aliases: true), regexp_resolver: "ecma")
    assert schema.ref("#/components/schemas/OperationEnvelope").valid?(json_response)
  end

  test "required finalization failure has a literal repair response through the HTTP boundary" do
    fail_next_domain_update(App, @app.id, "active", "test activation unavailable")
    transport = mock("SSH transport")
    transport.expects(:exec!).with do |command, options|
      options[:status][:exit_code] = 0
      command == "dokku ps:restart #{@app.dokku_id}"
    end
    Net::SSH.expects(:start).yields(transport)
    assert_raises(IOError) { ServerAction::Runner.new(@run).call }
    get "/api/v1/operations/#{@run.id}", headers: auth
    assert_response :ok
    assert_equal "failed", json_response.dig("operation", "status")
    assert_equal({"code" => "repair_required", "message" => "Repair required"}, json_response.dig("operation", "error"))
    schema = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join("docs/api/openapi.yml"), aliases: true), regexp_resolver: "ecma")
    assert_empty schema.schema("OperationEnvelope").validate(json_response).to_a
    assert @run.reload.remote_completed_at
    assert_nil @run.finalized_at
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
  end

  test "missing foreign and nonpublic runs are indistinguishable and scopes fail closed" do
    get "/api/v1/operations/#{@run.id}"
    assert_response :unauthorized
    @token.update!(scopes: ["apps:read"])
    get "/api/v1/operations/#{@run.id}", headers: auth
    assert_response :forbidden
    @token.update!(scopes: ["operations:read"], read_only: true)
    [ServerActionRun.maximum(:id) + 1, server_action_runs(:deploy_success).id].each do |id|
      get "/api/v1/operations/#{id}", headers: auth
      assert_response :not_found
    end
    @run.update_columns(account_id: accounts(:other).id)
    get "/api/v1/operations/#{@run.id}", headers: auth
    assert_response :not_found
  end

  test "public failures never include internal diagnostics and survive target deletion" do
    @run.update!(status: :error, public_error_code: "outcome_unknown", failure_message: "private-exception", finished_at: Time.current)
    @app.destroy!
    get "/api/v1/operations/#{@run.id}", headers: auth
    assert_response :ok
    assert_equal "failed", json_response.dig("operation", "status")
    assert_equal "outcome_unknown", json_response.dig("operation", "error", "code")
    assert_equal @app.id, json_response.dig("operation", "app_id")
    refute_includes response.body, "private-exception"
  end

  private

  def auth = {"Authorization" => "Bearer #{@secret}"}
end
