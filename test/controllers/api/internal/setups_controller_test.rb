require "test_helper"

class Api::Internal::SetupsControllerTest < ActionDispatch::IntegrationTest
  fixtures

  setup do
    @setup_token = "abc123456"
    @valid_params = {
      server: {
        name: "test.example.com",
        public_ip: "127.0.0.1",
        cpu_type: "arm64"
      },
      user: {
        email: "bobby.tables@example.com"
      }
    }
    @headers = {Authorization: "Bearer #{@setup_token}"}
    ENV["ACCOUNT_SETUP_TOKEN"] = @setup_token
  end

  test "#create returns a valid first run url" do
    Account.destroy_all
    User.destroy_all

    assert_difference ["Account.count", "Server.count", "User.count"], 1 do
      post api_internal_setups_url, params: @valid_params, headers: @headers
    end

    assert_response :success

    user_signed_id = json_response["first_run_url"].split("/").last
    user = User.find_signed!(user_signed_id, purpose: :first_run)

    assert_equal "bobby.tables@example.com", user.email

    account = user.accounts.last
    server = account.servers.last

    assert_equal "test.example.com", server.name
    assert_equal "127.0.0.1", server.public_ip
    assert_equal "arm64", server.cpu_type
  end

  test "#create returns an error if the setup token is invalid" do
    post api_internal_setups_url, params: @valid_params, headers: {Authorization: "Bearer invalid"}

    assert_response :unauthorized
    assert_equal "Invalid setup token", json_response["error"]
  end

  test "#create returns an error if an account already exists" do
    post api_internal_setups_url, params: @valid_params, headers: @headers

    assert_response :unprocessable_entity
    assert_equal "An account already exists", json_response["error"]
  end

  test "#create returns an error if the server params are invalid" do
    Account.destroy_all
    User.destroy_all

    params = @valid_params.merge(user: {email: "invalid"})
    post api_internal_setups_url, params:, headers: @headers

    assert_response :unprocessable_entity
    assert_equal "Validation failed: Email is invalid", json_response["error"]
  end
end
