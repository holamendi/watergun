require "test_helper"

class Github::InstallationAccessTokenTest < ActiveSupport::TestCase
  test "expired? returns false for future expiration" do
    token = github_installation_access_tokens(:valid)
    refute token.expired?
  end

  test "expired? returns true for past expiration" do
    token = github_installation_access_tokens(:expired)
    assert token.expired?
  end

  test "belongs to installation" do
    token = github_installation_access_tokens(:valid)
    assert_equal github_installations(:default), token.installation
  end

  test "belongs to account" do
    token = github_installation_access_tokens(:valid)
    assert_equal accounts(:default), token.account
  end
end
