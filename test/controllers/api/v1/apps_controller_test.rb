require "test_helper"

class Api::V1::AppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @app = apps(:smol_roda)
    @headers = auth_headers(api_tokens(:default))

    other_project = Project.create!(account: accounts(:other), server: servers(:other_server), name: "Other Project")
    @other_app = App.create!(
      account: accounts(:other),
      server: servers(:other_server),
      project: other_project,
      name: "Other App",
      dokku_id: "other-app"
    )
  end

  describe "authentication" do
    test "accepts an active token" do
      get api_v1_apps_url, headers: @headers

      assert_response :success
    end

    test "rejects an expired token" do
      get api_v1_apps_url, headers: auth_headers(api_tokens(:expired))

      assert_response :unauthorized
    end

    test "rejects an unknown token" do
      get api_v1_apps_url, headers: {Authorization: "Bearer unknown-token"}

      assert_response :unauthorized
    end

    test "rejects a request without a token" do
      get api_v1_apps_url

      assert_response :unauthorized
    end
  end

  describe "#index" do
    test "lists only the token account's apps" do
      get api_v1_apps_url, headers: @headers

      assert_response :success
      app_ids = json_response["apps"].map { it["id"] }
      assert_includes app_ids, @app.id
      assert_not_includes app_ids, @other_app.id
    end
  end

  describe "#show" do
    test "returns an app from the token account" do
      get api_v1_app_url(@app), headers: @headers

      assert_response :success
      assert_equal @app.id, json_response["app"]["id"]
    end

    test "does not return an app from another account" do
      get api_v1_app_url(@other_app), headers: @headers

      assert_response :not_found
    end
  end

  private

  def auth_headers(api_token)
    {Authorization: "Bearer #{api_token.token}"}
  end
end
