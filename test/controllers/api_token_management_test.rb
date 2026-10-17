require "test_helper"

class ApiTokenManagementTest < ActionDispatch::IntegrationTest
  test "authenticated owner issues a secret once and listings contain only safe metadata" do
    sign_in users(:bobby)
    assert_difference "ApiToken.count", 1 do
      post "/account/api_tokens", params: {api_token: {name: "automation", scopes: ["apps:read", "apps:write"]}}, as: :json
      assert_response :created
    end
    secret = json_response.fetch("secret")
    token = ApiToken.find(json_response.fetch("api_token").fetch("id"))
    assert_equal users(:bobby), token.user
    assert_equal accounts(:default), token.account
    assert_equal token.id, ApiToken.authenticate(secret).id
    get "/account/api_tokens", as: :json
    assert_response :success
    assert_equal [token.id], json_response.fetch("api_tokens").map { |record| record.fetch("id") }
    assert_not_includes response.body, secret
    assert_not_includes response.body, "token_digest"
    get "/account/api_tokens/#{token.id}", as: :json
    assert_response :success
    assert_not_includes response.body, secret
    assert_nil token.reload.token
    assert Object.const_defined?(:ApiTokenAudit), "token issuance must have durable audit records"
    audit = ApiTokenAudit.find_by(api_token: token, action: "issued")
    assert audit
    assert_equal users(:bobby), audit.user
    assert_equal accounts(:default), audit.account
    assert_not_includes audit.attributes.values.join, secret
  end

  test "rotation revokes the original atomically and revocation is idempotent" do
    sign_in users(:bobby)
    token = accounts(:default).api_tokens.create!(user: users(:bobby), name: "old", scopes: ["apps:read", "apps:write"])
    old_secret = token.token
    post "/account/api_tokens/#{token.id}/rotate", params: {api_token: {name: "new", scopes: ["apps:read"]}}, as: :json
    assert_response :created
    new_secret = json_response.fetch("secret")
    replacement = ApiToken.find(json_response.fetch("api_token").fetch("id"))
    assert_not_equal token.id, replacement.id
    assert token.reload.revoked_at
    assert_equal ["apps:read"], replacement.scopes
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{old_secret}"}
    assert_response :unauthorized
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{new_secret}"}
    assert_response :success
    2.times do
      delete "/account/api_tokens/#{replacement.id}", as: :json
      assert_response :success
      assert_not_includes response.body, new_secret
    end
    assert_equal 1, ApiTokenAudit.where(api_token: replacement, action: "revoked").count
    assert_equal 1, ApiTokenAudit.where(api_token: token, action: "rotated").count
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{new_secret}"}
    assert_response :unauthorized
  end

  test "legacy secrets can be claimed without guessing an owner or changing access" do
    legacy = accounts(:default).api_tokens.create!(name: "legacy", read_only: true)
    secret = legacy.token
    sign_in users(:bobby)
    post "/account/api_tokens/claim", params: {token: secret}, as: :json
    assert_response :success
    assert_equal users(:bobby), legacy.reload.user
    assert_equal ["apps:read"], legacy.scopes
    assert legacy.read_only?
    assert_not_includes response.body, secret
    assert_equal 1, ApiTokenAudit.where(api_token: legacy, action: "claimed").count
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{secret}"}
    assert_response :success
  end

  test "token management rejects absent browser authentication and other owners" do
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    get "/account/api_tokens", headers: {"Authorization" => "Bearer #{token.token}"}, as: :json
    assert_redirected_to "/login"
    other = User.create!(email: "other@example.test", password: "abc123456")
    Membership.create!(account: accounts(:default), user: other)
    sign_in other
    get "/account/api_tokens", as: :json
    assert_response :success
    assert_empty json_response.fetch("api_tokens")
    [[:get, "/account/api_tokens/#{token.id}"], [:delete, "/account/api_tokens/#{token.id}"], [:post, "/account/api_tokens/#{token.id}/rotate"], [:post, "/account/api_tokens/claim"]].each do |verb, path|
      public_send(verb, path, params: {token: token.token, api_token: {name: "steal", scopes: ["apps:write"]}}, as: :json)
      assert_response :not_found
    end
    assert_nil token.reload.revoked_at
    assert_equal users(:bobby), token.user
  end

  test "invalid rotation rolls back and token inputs cannot grant unknown scopes" do
    sign_in users(:bobby)
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    [["unknown"], ["apps:read", "apps:read"]].each do |scopes|
      assert_no_difference "ApiToken.count" do
        post "/account/api_tokens/#{token.id}/rotate", params: {api_token: {name: "invalid", scopes: scopes}}, as: :json
        assert_response :unprocessable_content
      end
      assert_nil token.reload.revoked_at
    end
    [1.second.ago, 2.years.from_now, "invalid"].each do |expiry|
      assert_no_difference "ApiToken.count" do
        post "/account/api_tokens", params: {api_token: {name: "invalid", scopes: ["apps:read"], expires_at: expiry}}, as: :json
        assert_response :unprocessable_content
      end
    end
    post "/account/api_tokens", params: {api_token: {name: "missing scope"}}, as: :json
    assert_response :bad_request
  end

  test "browser CSRF protection remains enforced for token issuance" do
    sign_in users(:bobby)
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "ApiToken.count" do
      post "/account/api_tokens", params: {api_token: {name: "csrf", scopes: ["apps:read"]}}, as: :json
      assert_response :unprocessable_content
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "audit rejection rolls back issuance and rotation without revoking the old token" do
    sign_in users(:bobby)
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    ApiTokenAudit.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(ApiTokenAudit.new))
    ["/account/api_tokens", "/account/api_tokens/#{token.id}/rotate"].each do |path|
      assert_no_difference "ApiToken.count" do
        post path, params: {api_token: {name: "audit failure", scopes: ["apps:read"]}}, as: :json
        assert_response :unprocessable_content
        assert_equal "validation_failed", json_response.dig("error", "code")
      end
      assert_nil token.reload.revoked_at
    end
  end

  test "actual request logs audit and instrumentation omit token material" do
    sign_in users(:bobby)
    output = StringIO.new
    original_rails_logger, original_record_logger = Rails.logger, ActiveRecord::Base.logger
    Rails.logger = ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
    captured = []
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") { |*args| captured << args.last[:params] }
    post "/account/api_tokens", params: {api_token: {name: "logging", scopes: ["apps:read"]}}, as: :json
    assert_response :created
    secret = json_response.fetch("secret")
    token = ApiToken.find(json_response.fetch("api_token").fetch("id"))
    get "/api/v1/apps", headers: {"Authorization" => "Bearer #{secret}"}
    assert_response :success
    post "/account/api_tokens", params: {api_token: {name: secret, scopes: [secret]}}, as: :json
    assert_response :unprocessable_content
    assert_not_includes response.body, secret
    assert_not_includes output.string, secret
    assert_not_includes output.string, token.token_digest
    assert_not_includes captured.to_json, secret
    assert_not_includes ApiTokenAudit.where(api_token: token).map(&:attributes).to_json, secret
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    Rails.logger, ActiveRecord::Base.logger = original_rails_logger, original_record_logger if original_rails_logger
  end
end
