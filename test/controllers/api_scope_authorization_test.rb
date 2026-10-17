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

  test "error request IDs are generated and do not trust caller input" do
    get "/api/v1/apps", headers: {"X-Request-ID" => "caller-controlled"}
    assert_response :unauthorized
    assert_not_equal "caller-controlled", response.headers["X-Request-ID"]
    assert_equal response.headers["X-Request-ID"], json_response.fetch("request_id")
  end
end
