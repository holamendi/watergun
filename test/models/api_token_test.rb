require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "active excludes expired tokens" do
    assert_includes ApiToken.active, api_tokens(:default)
    assert_not_includes ApiToken.active, api_tokens(:expired)
  end
end
