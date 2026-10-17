require "test_helper"

class ApiScopeProbeController < Api::V1::ApplicationController
  api_scope "apps:read", only: :index
  api_scope "apps:write", only: :create

  def index = head(:no_content)
  def create = head(:no_content)
  def undeclared = head(:no_content)
end

class ApiScopeAuthorizationTest < ActionDispatch::IntegrationTest
  test "read-only and scoped tokens cannot mutate and unclassified endpoints fail closed" do
    with_routing do |routes|
      routes.draw do
        post "/scope-probe", to: "api_scope_probe#create"
        get "/scope-probe", to: "api_scope_probe#index"
        get "/unclassified", to: "api_scope_probe#undeclared"
      end
      token = accounts(:default).api_tokens.create!(user: users(:bobby), scopes: ["apps:read", "apps:write"], read_only: true)
      headers = {"Authorization" => "Bearer #{token.token}"}
      post "/scope-probe", headers: headers
      assert_response :forbidden
      get "/scope-probe", headers: headers
      assert_response :no_content
      assert token.reload.last_used_at
      get "/unclassified", headers: headers
      assert_response :forbidden
      token.update!(read_only: false, scopes: ["apps:read"])
      post "/scope-probe", headers: headers
      assert_response :forbidden
      token.update!(scopes: ["apps:write"])
      post "/scope-probe", headers: headers
      assert_response :no_content
      get "/scope-probe", headers: headers
      assert_response :forbidden
    end
  end

  test "unknown and wrong-parent HTTP resources are consistently undisclosed" do
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    headers = {"Authorization" => "Bearer #{token.token}"}
    other = accounts(:default).apps.create!(name: "other", project: projects(:default), server: servers(:amd))
    get "/api/v1/apps/#{other.id}/deployments/#{deployments(:success_deployment).id}", headers: headers
    assert_response :not_found
    assert_equal "not_found", json_response.dig("error", "code")
    assert_equal response.headers["X-Request-ID"], json_response.fetch("request_id")
    get "/api/v1/apps/999999999/deployments", headers: headers
    assert_response :not_found
    foreign = Account.create!(name: "foreign")
    foreign_token = foreign.api_tokens.create!
    foreign_headers = {"Authorization" => "Bearer #{foreign_token.token}"}
    get "/api/v1/apps/#{apps(:smol_roda).id}", headers: foreign_headers
    assert_response :not_found
    get "/api/v1/apps/#{apps(:smol_roda).id}/deployments", headers: foreign_headers
    assert_response :not_found
    get "/api/v1/apps/#{apps(:smol_roda).id}/deployments/#{deployments(:success_deployment).id}", headers: foreign_headers
    assert_response :not_found
  end

  test "deployment reads require both account and parent ownership even for inconsistent rows" do
    foreign = Account.create!(name: "foreign")
    deployment = deployments(:success_deployment)
    deployment.update!(account: foreign)
    token = accounts(:default).api_tokens.create!
    headers = {"Authorization" => "Bearer #{token.token}"}
    app = apps(:smol_roda)

    get "/api/v1/apps/#{app.id}/deployments", headers: headers
    assert_response :success
    assert_not_includes json_response.fetch("deployments").map { |row| row.fetch("id") }, deployment.id
    get "/api/v1/apps/#{app.id}/deployments/#{deployment.id}", headers: headers
    assert_response :not_found
    foreign_token = foreign.api_tokens.create!
    with_routing do |routes|
      routes.draw { get "/deployment-probe/:id", to: "api/v1/deployments#show" }
      get "/deployment-probe/#{deployment.id}", headers: headers
      assert_response :not_found
      get "/deployment-probe/#{deployment.id}", headers: {"Authorization" => "Bearer #{foreign_token.token}"}
      assert_response :not_found
    end
  end

  test "embedded deployments also require the app account ownership" do
    foreign = Account.create!(name: "foreign")
    deployments(:success_deployment).update!(account: foreign)
    token = accounts(:default).api_tokens.create!
    headers = {"Authorization" => "Bearer #{token.token}"}
    app = apps(:smol_roda)

    get "/api/v1/apps/#{app.id}", headers: headers
    assert_response :success
    assert_nil json_response.fetch("app").fetch("deployment")
    get "/api/v1/apps", headers: headers
    assert_response :success
    assert_nil json_response.fetch("apps").find { |row| row.fetch("id") == app.id }.fetch("deployment")
  end

  test "embedded repository metadata requires matching account ownership" do
    app = apps(:smol_roda)
    app.github_repo.update!(account: Account.create!(name: "foreign"))
    token = accounts(:default).api_tokens.create!
    headers = {"Authorization" => "Bearer #{token.token}"}
    get "/api/v1/apps/#{app.id}", headers: headers
    assert_response :success
    assert_nil json_response.fetch("app").fetch("github_repo")
    get "/api/v1/apps", headers: headers
    assert_response :success
    assert_nil json_response.fetch("apps").find { |row| row.fetch("id") == app.id }.fetch("github_repo")
  end

  test "error request IDs are generated and do not trust caller input" do
    get "/api/v1/apps", headers: {"X-Request-ID" => "caller-controlled"}
    assert_response :unauthorized
    assert_not_equal "caller-controlled", response.headers["X-Request-ID"]
    assert_equal response.headers["X-Request-ID"], json_response.fetch("request_id")
  end
end
