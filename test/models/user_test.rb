require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "onboarding tokens expire after one day" do
    freeze_time do
      user = users(:bobby)
      token = user.generate_token_for(:first_run)
      assert_equal user, User.find_by_token_for(:first_run, token)

      travel 1.day + 1.second
      assert_nil User.find_by_token_for(:first_run, token)
    end
  end

  test "changing a password invalidates onboarding tokens" do
    user = users(:bobby)
    token = user.generate_token_for(:first_run)
    user.update!(password: "changed-password")

    assert_nil User.find_by_token_for(:first_run, token)
  end

  test "onboarding tokens expose only the password salt suffix" do
    user = users(:bobby)
    token = user.generate_token_for(:first_run)
    payload = User.generated_token_verifier.verified(token, purpose: "User\nfirst_run\n#{1.day}")

    assert_equal [user.id, user.password_salt.last(10)], payload
  end
end
