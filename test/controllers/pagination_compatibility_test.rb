require "test_helper"

class PaginationCompatibilityTest < ActionDispatch::IntegrationTest
  test "API pagination preserves account scope and public headers" do
    account = accounts(:default)
    template = apps(:smol_roda).attributes.except("id", "name", "dokku_id")
    App.insert_all!(21.times.map { |i| template.merge("name" => "Pagination #{i}", "dokku_id" => "pagination-#{i}") })
    token = account.api_tokens.create!
    get "/api/v1/apps", params: {page: 2}, headers: {"Authorization" => "Bearer #{token.token}"}
    assert_response :success
    assert_equal "2", response.headers["Current-Page"]
    assert_equal "20", response.headers["Page-Items"]
    assert_equal "23", response.headers["Total-Count"]
    assert_equal "2", response.headers["Total-Pages"]
    assert_match(/rel="prev"/, response.headers["Link"])
    assert_equal 3, json_response.fetch("apps").size
  end

  test "empty API pages keep their original pagination headers" do
    account = accounts(:default)
    account.apps.update_all(discarded_at: Time.current)
    token = account.api_tokens.create!
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{token.token}"}
    assert_response :success
    assert_equal "0", response.headers["Total-Count"]
    assert_equal "1", response.headers["Total-Pages"]
    assert_equal "1", response.headers["Current-Page"]
    assert_empty json_response.fetch("apps")
  end

  test "out-of-range API pages still raise rather than silently clamp" do
    token = accounts(:default).api_tokens.create!
    assert_raises(Pagy::RangeError) do
      get "/api/v1/apps", params: {page: 999}, headers: {"Authorization" => "Bearer #{token.token}"}
    end
  end

  test "long pagination retains the seven-slot window" do
    template = server_action_runs(:deploy_success).attributes.except("id")
    ServerActionRun.insert_all!(201.times.map { template })
    sign_in users(:bobby)
    get server_actions_url
    assert_response :success
    assert_select ".join a[href*='page=5']", count: 1
    assert_select ".join a[href*='page=6']", count: 0
  end

  test "server action pagination retains custom buttons and query links" do
    template = server_action_runs(:deploy_success).attributes.except("id")
    ServerActionRun.insert_all!(26.times.map { template })
    sign_in users(:bobby)
    get server_actions_url
    assert_response :success
    assert_select "a[aria-label='Next page'][href*='page=2']"
    assert_select ".join .btn-active", text: "1"
    get server_actions_url(page: 2)
    assert_response :success
    assert_select "a[aria-label='Previous page'][href*='page=1']"
    assert_select ".join .btn-active", text: "2"
  end
end
