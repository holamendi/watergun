require "test_helper"

class FirstRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Account.destroy_all
    User.destroy_all
    @previous_setup_token = ENV["ACCOUNT_SETUP_TOKEN"]
    ENV["ACCOUNT_SETUP_TOKEN"] = "first-run-test-token"
    post api_internal_setups_path,
      params: {server: {name: "Test", public_ip: "127.0.0.1", cpu_type: "arm64"}, user: {email: "onboarding@example.com"}},
      headers: {Authorization: "Bearer first-run-test-token"}
    assert_response :success
    @first_run_url = json_response.fetch("first_run_url")
    @token = Rack::Utils.parse_query(URI(@first_run_url).query).fetch("token")
    @user = User.find_by!(email: "onboarding@example.com")
    @password = "new-onboarding-password"
  end

  teardown do
    ENV["ACCOUNT_SETUP_TOKEN"] = @previous_setup_token
  end

  test "setup link completes onboarding and signs the user in" do
    get @first_run_url
    assert_response :success
    assert_select "form[action='#{first_run_path}'][method='post']" do
      assert_select "input[name='_method'][value='patch']"
      assert_select "input[type='hidden'][name='token'][value=?]", @token
    end

    assert_difference "Session.count", 1 do
      complete_onboarding
    end
    assert_redirected_to root_path
    assert @user.reload.authenticate(@password)
  end

  test "a consumed link cannot change the password again" do
    complete_onboarding
    digest = @user.reload.password_digest

    assert_no_difference "Session.count" do
      complete_onboarding(password: "another-password")
    end
    assert_response :not_found
    assert_equal digest, @user.reload.password_digest
  end

  test "a link expires after one day" do
    travel 1.day + 1.second do
      complete_onboarding
      assert_response :not_found
      get edit_first_run_path(token: @token)
      assert_response :not_found
    end
  end

  test "legacy signed links are rejected" do
    @token = @user.signed_id(purpose: :first_run)
    complete_onboarding
    assert_response :not_found
  end

  test "a password is required and validation leaves the link usable" do
    patch first_run_path, params: {token: @token, user: {email: "changed@example.com"}}
    assert_response :unprocessable_content
    assert_equal "onboarding@example.com", @user.reload.email

    complete_onboarding
    assert_redirected_to root_path
  end

  test "invalid confirmation leaves the link usable" do
    patch first_run_path, params: {token: @token, user: {password: @password, password_confirmation: "different"}}
    assert_response :unprocessable_content

    complete_onboarding
    assert_redirected_to root_path
  end

  private

  def complete_onboarding(password: @password)
    patch first_run_path, params: {token: @token, user: {password:, password_confirmation: password}}
  end
end
