require "test_helper"
require "rake"

class FirstRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:bobby)
    @token = @user.signed_id(expires_in: 1.day, purpose: :first_run_v2)
    @user_params = {email: "onboarded@example.com", password: "new-password", password_confirmation: "new-password"}
  end

  test "expired onboarding tokens cannot read or update credentials" do
    digest = @user.password_digest
    travel 1.day + 1.second do
      get pretty_first_run_url(signed_id: @token)
      assert_response :not_found

      assert_no_difference "Session.count" do
        patch first_run_url, params: {signed_id: @token, user: @user_params}
      end
      assert_response :not_found
    end
    assert_equal digest, @user.reload.password_digest
    assert_nil @user.first_run_completed_at
  end

  test "completion is rechecked after locking a stale user" do
    stale_user = User.find(@user.id)
    @user.update!(first_run_completed_at: Time.current)
    digest = @user.password_digest
    # Model a request that resolved its token before another request completed.
    User.stubs(:find_signed!).with(@token, purpose: :first_run_v2).returns(stale_user)

    assert_no_difference "Session.count" do
      patch first_run_url, params: {signed_id: @token, user: @user_params}
    end
    assert_response :not_found
    assert_equal digest, @user.reload.password_digest
    assert_equal "bobby.tables@example.com", @user.email
  end

  test "legacy tokens cannot update credentials" do
    legacy_token = @user.signed_id(purpose: :first_run)
    digest = @user.password_digest
    assert_no_difference "Session.count" do
      patch first_run_url, params: {signed_id: legacy_token, user: @user_params}
    end
    assert_response :not_found
    assert_equal digest, @user.reload.password_digest
  end

  test "onboarding requires a new password" do
    assert_no_difference "Session.count" do
      patch first_run_url, params: {signed_id: @token, user: {email: "onboarded@example.com"}}
    end
    assert_response :unprocessable_content
    assert_nil @user.reload.first_run_completed_at
    assert_equal "bobby.tables@example.com", @user.email
  end

  test "account setup task issues an accepted expiring onboarding token" do
    Account.destroy_all
    User.destroy_all
    Rails.application.load_tasks unless Rake::Task.task_defined?("account:setup")
    task = Rake::Task["account:setup"]
    original_argv = ARGV.dup
    ARGV.replace(["account:setup", "test.example.com", "127.0.0.1", "arm64", "watergun.example.com", "operator@example.com"])

    freeze_time do
      output, = capture_io { task.execute }
      token = JSON.parse(output.lines.find { |line| line.start_with?("ACCOUNT_DATA:") }.delete_prefix("ACCOUNT_DATA:"))["token"]
      get pretty_first_run_url(signed_id: token)
      assert_response :success

      travel 1.day + 1.second
      get pretty_first_run_url(signed_id: token)
      assert_response :not_found
    end
  ensure
    ARGV.replace(original_argv) if original_argv
    Current.reset
  end

  test "invalid credentials leave the token usable" do
    digest = @user.password_digest
    assert_no_difference "Session.count" do
      patch first_run_url, params: {signed_id: @token, user: @user_params.merge(password_confirmation: "mismatch")}
    end
    assert_response :unprocessable_content
    assert_nil @user.reload.first_run_completed_at
    assert_equal digest, @user.password_digest
    assert_select "input[name=signed_id][value=?]", @token

    patch first_run_url, params: {signed_id: @token, user: @user_params}
    assert_redirected_to root_url
    assert @user.reload.authenticate("new-password")
  end

  test "legacy unexpiring tokens cannot open onboarding" do
    legacy_token = @user.signed_id(purpose: :first_run)
    get pretty_first_run_url(signed_id: legacy_token)
    assert_response :not_found
  end

  test "completed onboarding cannot reopen the form" do
    patch first_run_url, params: {signed_id: @token, user: @user_params}
    assert_redirected_to root_url

    get pretty_first_run_url(signed_id: @token)
    assert_response :not_found
  end

  test "completed onboarding cannot reset credentials with the same token" do
    assert_difference "Session.count", 1 do
      patch first_run_url, params: {signed_id: @token, user: @user_params}
    end
    assert_redirected_to root_url
    digest = @user.reload.password_digest

    assert_no_difference "Session.count" do
      patch first_run_url, params: {signed_id: @token, user: @user_params.merge(email: "attacker@example.com")}
    end
    assert_response :not_found
    assert_equal "onboarded@example.com", @user.reload.email
    assert_equal digest, @user.password_digest
  end
end
