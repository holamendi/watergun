require "test_helper"

class MissionControlAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_admin_ids = ENV["JOBS_ADMIN_USER_IDS"]
    ENV.delete("JOBS_ADMIN_USER_IDS")
  end

  teardown do
    ENV["JOBS_ADMIN_USER_IDS"] = @previous_admin_ids
  end

  test "ordinary sessions cannot access global jobs by default" do
    sign_in users(:bobby)

    get "/jobs"

    assert_response :forbidden
  end

  test "explicitly allowlisted sessions can access jobs" do
    ENV["JOBS_ADMIN_USER_IDS"] = "999999, #{users(:bobby).id} "
    sign_in users(:bobby)

    get "/jobs"

    assert_response :success
  end

  test "allowlisting another user does not grant access" do
    ENV["JOBS_ADMIN_USER_IDS"] = "#{users(:bobby).id}0,invalid,*"
    sign_in users(:bobby)

    get "/jobs"

    assert_response :forbidden
  end

  test "anonymous requests must sign in even when an admin is configured" do
    ENV["JOBS_ADMIN_USER_IDS"] = users(:bobby).id.to_s

    get "/jobs"

    assert_redirected_to "/login"
  end

  test "ordinary sessions cannot invoke job mutations" do
    sign_in users(:bobby)

    assert_no_difference "SolidQueue::Pause.count" do
      post "/jobs/applications/watergun/queues/default/pause"
    end

    assert_response :forbidden
  end

  test "ordinary sessions cannot access nested job pages" do
    sign_in users(:bobby)

    get "/jobs/applications/watergun/failed/jobs"

    assert_response :forbidden
  end
end
