require "test_helper"

class Github::InstallationTest < ActiveSupport::TestCase
  setup do
    @installation = github_installations(:default)
  end

  test "access_token returns latest access token" do
    token = @installation.access_token

    assert_instance_of Github::InstallationAccessToken, token
    assert_equal github_installation_access_tokens(:valid), token
  end

  test "access_token_expired? returns false for valid token" do
    refute @installation.access_token_expired?
  end

  test "access_token_expired? returns true when no token exists" do
    installation = Github::Installation.create!(
      account: accounts(:default),
      github_app: github_apps(:default),
      installation_id: 999999,
      login: "newuser"
    )

    assert installation.access_token_expired?
  end

  test "access_token_expired? returns true for expired token" do
    installation = github_installations(:expired_token)

    assert installation.access_token_expired?
  end

  test "api_client uses existing valid token" do
    # Should not make API call if token is valid
    client = @installation.api_client

    assert_instance_of Octokit::Client, client
  end

  test "belongs to account" do
    assert_equal accounts(:default), @installation.account
  end

  test "belongs to github_app" do
    assert_equal github_apps(:default), @installation.github_app
  end

  test "has many access_tokens" do
    assert_respond_to @installation, :access_tokens
  end

  test "has many events" do
    assert_respond_to @installation, :events
  end
end
