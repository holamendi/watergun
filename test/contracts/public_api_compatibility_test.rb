require "test_helper"
require "json_schemer"

class PublicApiCompatibilityTest < ActionDispatch::IntegrationTest
  setup do
    @headers = {"Authorization" => "Bearer #{accounts(:default).api_tokens.create!.token}"}
    @contract = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join("docs/api/openapi.yml"), aliases: true), regexp_resolver: "ecma")
  end

  test "existing app and deployment HTTP reads match the preserved schemas" do
    app = apps(:smol_roda)
    deployment = deployments(:success_deployment)
    {
      "/api/v1/apps" => "Apps",
      "/api/v1/apps/#{app.id}" => "AppEnvelope",
      "/api/v1/apps/#{app.id}/deployments" => "Deployments",
      "/api/v1/apps/#{app.id}/deployments/#{deployment.id}" => "DeploymentEnvelope",
      "/api/v1/apps/#{app.id}/ping" => "Pong"
    }.each do |path, schema|
      get path, headers: @headers
      assert_response :success
      errors = @contract.schema(schema).validate(json_response).map { |error| [error["data_pointer"], error["type"]] }
      assert_empty errors, "#{path}: #{errors.inspect}"
    end
  end

  test "ping remains an authentication probe even for an absent app" do
    get "/api/v1/apps/999999999/ping", headers: @headers
    assert_response :success
    assert_equal({"pong" => true}, json_response)
  end

  test "contract rejects invalid env batches and unsafe public fields" do
    env = @contract.schema("EnvWrite")
    assert env.valid?({"mode" => "merge", "values" => {"EMPTY" => "", "DELETE" => nil}})
    assert_not env.valid?({"mode" => "merge", "values" => {"DOKKU_SECRET" => "value"}})
    assert_not env.valid?({"mode" => "merge", "values" => {"VALID" => "value\u0000"}})
    assert_not env.valid?({"mode" => "merge", "values" => {"INVALID-NAME" => "value"}})
    assert_not env.valid?({"mode" => "unknown", "values" => {}})
    assert_not @contract.schema("OperationEnvelope").valid?({"operation" => {"payload" => "secret"}})
    assert_not @contract.schema("ErrorEnvelope").valid?({"error" => {"code" => "invalid_request", "message" => "Invalid", "payload" => "secret"}, "request_id" => "test"})
  end

  test "app and deployment schemas reject credential fields on otherwise valid responses" do
    app = apps(:smol_roda)
    get "/api/v1/apps/#{app.id}", headers: @headers
    data = json_response
    assert @contract.schema("AppEnvelope").valid?(data)
    data.fetch("app")["deploy_token"] = "sentinel"
    assert_not @contract.schema("AppEnvelope").valid?(data)

    get "/api/v1/apps/#{app.id}/deployments/#{deployments(:success_deployment).id}", headers: @headers
    data = json_response
    assert @contract.schema("DeploymentEnvelope").valid?(data)
    data.fetch("deployment")["payload"] = {"secret" => "sentinel"}
    assert_not @contract.schema("DeploymentEnvelope").valid?(data)
  end

  test "schema validation rejects multiline names values and commit identifiers" do
    env = @contract.schema("EnvWrite")
    assert_not env.valid?({"mode" => "merge", "values" => {"A\nBAD-NAME" => "value"}})
    assert_not env.valid?({"mode" => "merge", "values" => {"VALID" => "ok\n\u0000secret"}})
    assert_not @contract.schema("DeploymentCreate").valid?({"sha" => "#{"a" * 40}\nignored"})
  end

  test "persisted internal mutations do not become public resource fields" do
    app = apps(:smol_roda)
    variable = app.env_variables.new(name: "PRIVATE_EXAMPLE", value: "serialization-secret-only")
    assert variable.save_and_sync
    run = app.server_action_runs.where(action_key: "apps.update_env").order(:id).last
    assert_equal "serialization-secret-only", run.reload.payload.dig("set", "PRIVATE_EXAMPLE")
    get "/api/v1/apps/#{app.id}", headers: @headers
    assert_response :success
    assert @contract.schema("AppEnvelope").valid?(json_response)
    %w[payload action_key failure_message ssh_commands serialization-secret-only deploy_token].each do |internal|
      refute_includes response.body, internal
    end
  end
end
