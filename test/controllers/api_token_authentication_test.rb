require "test_helper"

class ApiTokenAuthenticationTest < ActionDispatch::IntegrationTest
  test "expired bearer tokens cannot authenticate" do
    token = accounts(:default).api_tokens.create!(expires_at: 1.second.ago)

    get api_v1_app_ping_url(apps(:smol_roda)), headers: {"Authorization" => "Bearer #{token.token}"}

    assert_response :unauthorized
  end

  test "bearer tokens expire at the exact expiry instant" do
    travel_to Time.current.change(usec: 0) do
      token = accounts(:default).api_tokens.create!(expires_at: Time.current)

      get api_v1_app_ping_url(apps(:smol_roda)), headers: {"Authorization" => "Bearer #{token.token}"}

      assert_response :unauthorized
    end
  end

  test "unexpired bearer tokens still authenticate" do
    travel_to Time.current.change(usec: 0) do
      token = accounts(:default).api_tokens.create!(expires_at: 1.second.from_now)

      get api_v1_app_ping_url(apps(:smol_roda)), headers: {"Authorization" => "Bearer #{token.token}"}

      assert_response :success
      assert_equal({"pong" => true}, json_response)
    end
  end

  test "unknown bearer tokens are rejected" do
    get api_v1_app_ping_url(apps(:smol_roda)), headers: {"Authorization" => "Bearer nonexistent"}

    assert_response :unauthorized
  end

  test "missing bearer tokens are rejected" do
    get api_v1_app_ping_url(apps(:smol_roda))

    assert_response :unauthorized
  end

  test "revoked tokens and insufficient scopes are rejected through HTTP" do
    token = accounts(:default).api_tokens.create!(scopes: [])
    headers = {"Authorization" => "Bearer #{token.token}"}
    get api_v1_app_ping_url(apps(:smol_roda)), headers: headers
    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")

    token.update!(scopes: ["apps:read"], revoked_at: Time.current)
    get api_v1_app_ping_url(apps(:smol_roda)), headers: headers
    assert_response :unauthorized
    assert_equal "unauthorized", json_response.dig("error", "code")
  end

  test "removed owner membership invalidates owned token authentication" do
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    Membership.where(user: users(:bobby), account: accounts(:default)).delete_all
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{token.token}"}
    assert_response :unauthorized
  end
end
