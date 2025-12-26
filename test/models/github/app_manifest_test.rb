require "test_helper"

class Github::AppManifestTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:default)
    @manifest = Github::AppManifest.new(account: @account)
    Rails.application.routes.default_url_options[:host] = "example.com"
  end

  test "registration_url includes signed state parameter" do
    url = @manifest.registration_url

    assert url.starts_with?("https://github.com/settings/apps/new?state=")

    # Verify the state can be decoded
    state = URI.decode_www_form(URI(url).query).to_h["state"]
    decoded_account = Account.find_signed(state, purpose: :github_app_registration)

    assert_equal @account, decoded_account
  end

  test "to_param returns valid JSON with required fields" do
    json = @manifest.to_param
    data = JSON.parse(json)

    assert_equal "Watergun", data["name"]
    assert_equal false, data["public"]
    assert_equal "A private GitHub App for managing your Watergun projects", data["description"]
    assert data["url"].present?
    assert data["redirect_url"].present?
    assert data["setup_url"].present?
    assert_equal({"checks" => "read", "contents" => "read"}, data["default_permissions"])
    assert_equal ["check_suite", "push"], data["default_events"]
    assert data["hook_attributes"]["url"].present?
  end

  test "accepts custom name and description" do
    manifest = Github::AppManifest.new(
      account: @account,
      name: "Custom App",
      description: "Custom description"
    )

    data = JSON.parse(manifest.to_param)

    assert_equal "Custom App", data["name"]
    assert_equal "Custom description", data["description"]
  end
end
