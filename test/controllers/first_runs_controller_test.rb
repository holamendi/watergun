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
    @token = json_response.fetch("first_run_url").split("/").last
    @user = User.find_by!(email: "onboarding@example.com")
    @password = "new-onboarding-password"
  end

  teardown do
    ENV["ACCOUNT_SETUP_TOKEN"] = @previous_setup_token
  end

  test "setup link completes onboarding and signs the user in" do
    get pretty_first_run_path(@token)
    assert_response :success
    assert_select "form[action='#{first_run_path}'][method='post']" do
      assert_select "input[name='_method']", count: 0
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
      get pretty_first_run_path(@token)
      assert_response :not_found
    end
  end

  test "legacy signed links are rejected" do
    @token = @user.signed_id(purpose: :first_run)
    complete_onboarding
    assert_response :not_found
  end

  test "a password is required and validation leaves the link usable" do
    post first_run_path, params: {signed_id: @token, user: {email: "changed@example.com"}}
    assert_response :unprocessable_content
    assert_equal "onboarding@example.com", @user.reload.email

    complete_onboarding
    assert_redirected_to root_path
  end

  test "invalid confirmation leaves the link usable" do
    post first_run_path, params: {signed_id: @token, user: {password: @password, password_confirmation: "different"}}
    assert_response :unprocessable_content

    complete_onboarding
    assert_redirected_to root_path
  end

  private

  def complete_onboarding(password: @password)
    post first_run_path, params: {signed_id: @token, user: {password:, password_confirmation: password}}
  end
end

class FirstRunConsumptionRaceTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  test "two requests that validate the same link can only consume it once" do
    user = accounts(:default).users.create!(email: "onboarding-race@example.com", password: "initial-password")
    token = user.generate_token_for(:first_run)
    requests = []

    user.with_lock do
      requests = 2.times.map do |index|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            client = ActionDispatch::Integration::Session.new(Rails.application)
            password = "onboarding-password-#{index}"
            client.post first_run_path, params: {signed_id: token, user: {password:, password_confirmation: password}}
            client.response.status
          end
        end
      end

      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        Timeout.timeout(5) do
          loop do
            User.connection.execute("SELECT pg_stat_clear_snapshot()")
            waiting = User.connection.select_value(<<~SQL).to_i
              SELECT COUNT(*) FROM pg_stat_activity
              WHERE datname = current_database() AND wait_event_type = 'Lock'
                AND query LIKE '%"users"%' AND query LIKE '%FOR UPDATE%'
            SQL
            break if waiting == 2
            sleep 0.01
          end
        end
      end
    end

    assert_equal [302, 404], requests.map(&:value).sort
    assert_equal 1, user.sessions.count
  ensure
    requests&.each(&:join)
    user&.destroy!
  end
end
