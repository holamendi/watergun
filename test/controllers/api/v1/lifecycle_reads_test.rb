require "test_helper"
require "json_schemer"

class Api::V1::LifecycleReadsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @token = ApiToken.create!(account: @project.account, user: users(:bobby), scopes: ["apps:read"])
    @headers = {"Authorization" => "Bearer #{@token.token}"}
  end

  test "projects and project apps are bounded ordered explicitly server scoped and contract compatible" do
    get "/api/v1/projects?limit=1", headers: @headers
    assert_response :ok
    assert_equal [Project.kept.order(:id).first.id], json_response.fetch("projects").map { |row| row.fetch("id") }
    assert_equal "1", response.headers["Page-Items"]
    assert_equal "1", response.headers["Current-Page"]
    assert_includes response.headers["Link"], 'rel="next"'
    assert_schema "Projects"
    get "/api/v1/projects/#{@project.id}/apps?limit=1", headers: @headers
    assert_response :ok
    assert_equal [@project.apps.order(:id).first.id], json_response.fetch("apps").map { |row| row.fetch("id") }
    assert_schema "Apps"
    get "/api/v1/apps?limit=1&page=9999", headers: @headers
    assert_response :ok
    assert_equal [], json_response.fetch("apps")
  end

  test "deployment listing is bounded without changing root fields or ping" do
    app = apps(:smol_roda)
    get "/api/v1/apps/#{app.id}/deployments?limit=1", headers: @headers
    assert_response :ok
    assert_equal 1, json_response.fetch("deployments").length
    assert_equal "1", response.headers["Page-Items"]
    assert_schema "Deployments"
    get "/api/v1/apps/#{app.id}", headers: @headers
    assert_response :ok
    assert_schema "AppEnvelope"
    get "/api/v1/apps/999999/ping", headers: @headers
    assert_response :ok
    assert_equal({"pong" => true}, json_response)
  end

  test "list parameters cannot disable limits and wrong parents never broaden lookup" do
    ["limit=101", "limit=0", "page=0", "page=-1", "limit[]=1", "page=1.5", "limit=no", "anything=1"].each do |query|
      ["/api/v1/projects", "/api/v1/apps", "/api/v1/apps/#{apps(:smol_roda).id}/deployments"].each do |path|
        get "#{path}?#{query}", headers: @headers
        assert_response :bad_request
        assert_equal "invalid_request", json_response.dig("error", "code")
      end
    end
    get "/api/v1/projects/#{projects(:arm_project).id}/apps", headers: @headers
    assert_response :ok
    assert_equal [], json_response.fetch("apps")
    get "/api/v1/projects/999999/apps", headers: @headers
    assert_response :not_found
  end

  test "inconsistent account project and server ancestry is hidden on every read" do
    app = apps(:smol_roda)
    @project.update_columns(account_id: accounts(:other).id)
    get "/api/v1/apps/#{app.id}", headers: @headers
    assert_response :not_found
    get "/api/v1/apps/#{app.id}/deployments", headers: @headers
    assert_response :not_found
    get "/api/v1/projects/#{@project.id}/apps", headers: @headers
    assert_response :not_found
    get "/api/v1/apps", headers: @headers
    assert_response :ok
    assert_equal [], json_response.fetch("apps")
  end

  test "additive app status context and env names are inspectable without secret values" do
    app = apps(:domain_test_app)
    app.env_variables.create!(name: "VISIBLE_NAME", value: "private-env-sentinel")
    get "/api/v1/apps/#{app.id}", headers: @headers
    assert_response :ok
    body = json_response.fetch("app")
    assert_equal "active", body.fetch("status")
    assert_equal app.project_id, body.fetch("project_id")
    assert_equal app.server_id, body.fetch("server_id")
    assert_equal ["VISIBLE_NAME"], body.fetch("env_names")
    assert_equal "http://domain-test-app.local.watergun.dev", body.fetch("url")
    refute_match(/private-env-sentinel|deploy_token|payload|private_key/, response.body)
    assert_schema "AppEnvelope"
  end

  private

  def assert_schema(name)
    schema = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join("docs/api/openapi.yml"), aliases: true), regexp_resolver: "ecma")
    assert schema.ref("#/components/schemas/#{name}").valid?(json_response)
  end
end
