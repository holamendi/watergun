require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "new secrets are transient and only digests persist" do
    assert_respond_to ApiToken, :authenticate
    token = accounts(:default).api_tokens.create!(user: users(:bobby), name: "test")
    secret = token.token
    assert_match(/\Awg_[A-Za-z0-9_-]{43}\z/, secret)
    row = ApiToken.connection.select_one("SELECT * FROM api_tokens WHERE id = #{token.id}")
    assert_not row.values.any? { |value| value.to_s.include?(secret) }
    assert_equal Digest::SHA256.hexdigest(secret), row.fetch("token_digest")
    assert_equal token.id, ApiToken.authenticate(secret).id
    assert_nil ApiToken.find(token.id).token
    assert_not_includes token.as_json.keys, "token_digest"
    assert_not_includes token.inspect, secret
  end
end
