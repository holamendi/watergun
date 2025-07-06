require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_session_url
    assert_response :success
  end

  test "create with valid credentials creates a session" do
    assert_difference "Session.count" do
      post session_url, params: {session: {email: "bobby.tables@example.com", password: "abc123456"}}
      assert_redirected_to root_url
    end
  end

  test "create with invalid credentials does not create a session" do
    assert_no_difference "Session.count" do
      post session_url, params: {session: {email: "bobby.tables@example.com", password: "wrong_password"}}
      assert_response :unprocessable_entity
    end
  end

  test "destroy destroys the session" do
    sign_in :bobby

    assert_difference "Session.count", -1 do
      delete session_url
      assert_redirected_to login_url
    end
  end
end
