require "test_helper"

class Github::AppTest < ActiveSupport::TestCase
  setup do
    @github_app = github_apps(:default)
  end

  test "generates valid JWT bearer token" do
    token = @github_app.send(:bearer_token)

    decoded = JWT.decode(token, @github_app.send(:private_key).public_key, true, algorithm: "RS256")
    payload = decoded.first

    assert_equal @github_app.client_id, payload["iss"]
    assert payload["iat"].present?
    assert payload["exp"].present?
    assert payload["exp"] > payload["iat"]
  end

  test "creates Octokit API client with bearer token" do
    client = @github_app.api_client

    assert_instance_of Octokit::Client, client
    assert client.instance_variable_get(:@bearer_token).present?
  end

  test "generates new installation URL" do
    expected_url = "#{@github_app.html_url}/installations/new"
    assert_equal expected_url, @github_app.new_installation_url
  end

  test "parses private key from PEM" do
    private_key = @github_app.send(:private_key)

    assert_instance_of OpenSSL::PKey::RSA, private_key
  end

  test "belongs to account" do
    assert_equal accounts(:default), @github_app.account
  end

  test "has many installations" do
    assert_respond_to @github_app, :installations
  end
end
