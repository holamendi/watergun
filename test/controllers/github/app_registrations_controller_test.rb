require "test_helper"
require "ostruct"

class Github::AppRegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @account.github_app&.destroy
    @user = users(:bobby)
    sign_in @user
  end

  test "callback creates GitHub App from manifest conversion" do
    state = @account.signed_id(purpose: :github_app_registration)
    code = "test_manifest_code_123"

    VCR.use_cassette("github/app_manifest_conversion") do
      assert_difference -> { Github::App.count }, 1 do
        get github_app_registrations_callback_url, params: {code: code, state: state}
      end
    end

    github_app = @account.reload.github_app

    assert github_app.present?
    assert_equal 123456, github_app.app_id
    assert github_app.client_id.present?
    assert github_app.client_secret.present?
    assert github_app.pem.present?
    assert github_app.webhook_secret.present?
    assert_redirected_to github_app.new_installation_url
  end

  test "callback fails with invalid manifest code" do
    state = @account.signed_id(purpose: :github_app_registration)
    code = "invalid_code"

    VCR.use_cassette("github/app_manifest_conversion_invalid") do
      assert_no_difference -> { Github::App.count } do
        get github_app_registrations_callback_url, params: {code: code, state: state}
      end
    end

    assert_redirected_to account_path
    assert_equal "Invalid manifest code", flash[:error]
  end

  test "callback fails with invalid state parameter" do
    invalid_state = "invalid_state_token"
    code = "test_code"

    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      get github_app_registrations_callback_url, params: {code: code, state: invalid_state}
    end
  end

  test "callback fails when state belongs to different account" do
    other_account = Account.create!(name: "Other Account")
    state = other_account.signed_id(purpose: :github_app_registration)
    code = "test_code"

    # No HTTP stub needed - should redirect before making any API calls

    get github_app_registrations_callback_url, params: {code: code, state: state}

    assert_redirected_to account_path
    assert_equal "Invalid manifest code", flash[:error]
  end
end
