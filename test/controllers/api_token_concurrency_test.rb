require "test_helper"
require "timeout"

class ApiTokenConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    ApiTokenAudit.delete_all
    ApiToken.delete_all
    Session.delete_all
  end

  test "competing rotations issue only one replacement and one rotation audit" do
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    sessions = [browser(users(:bobby)), browser(users(:bobby))]
    results = competing_requests(token, sessions, [:rotate, :rotate])
    assert_equal [201, 404], results.map(&:status).sort
    assert token.reload.revoked_at
    assert_equal 1, ApiTokenAudit.where(api_token: token, action: "rotated").count
    assert_equal 1, ApiTokenAudit.where(action: "issued").count
    issued = JSON.parse(results.find { |result| result.status == 201 }.body)
    assert ApiToken.authenticate(issued.fetch("secret"))
  end

  test "competing rotation and revocation cannot resurrect the original" do
    token = accounts(:default).api_tokens.create!(user: users(:bobby))
    secret = token.token
    sessions = [browser(users(:bobby)), browser(users(:bobby))]
    results = competing_requests(token, sessions, [:rotate, :revoke])
    assert_includes [201, 404], results.first.status
    assert_equal 200, results.last.status
    assert_nil ApiToken.authenticate(secret)
    assert_equal 1, ApiTokenAudit.where(api_token: token).count
    assert_equal (results.first.status == 201) ? 1 : 0, ApiTokenAudit.where(action: "issued").count
  end

  test "competing legacy claims assign exactly one owner and audit" do
    token = accounts(:default).api_tokens.create!
    other = User.create!(email: "concurrent-owner@example.test", password: "abc123456")
    Membership.create!(account: accounts(:default), user: other)
    sessions = [browser(users(:bobby)), browser(other)]
    results = competing_requests(token, sessions, [:claim, :claim])
    assert_equal [200, 404], results.map(&:status).sort
    winner = (results.first.status == 200) ? users(:bobby) : other
    assert_equal winner.id, token.reload.user_id
    assert_equal 1, ApiTokenAudit.where(api_token: token, action: "claimed", user: winner).count
    assert_equal 1, ApiTokenAudit.where(api_token: token).count
  end

  private

  def browser(user)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post "/session", params: {session: {email: user.email, password: "abc123456"}}
    assert_equal 302, session.response.status
    assert session.cookies[:session_token].present?
    session
  end

  def competing_requests(token, sessions, actions)
    pids = Queue.new
    threads = []
    secret = token.token
    token.with_lock do
      threads = sessions.zip(actions).map do |session, action|
        Thread.new do
          ApiToken.connection_pool.with_connection do |connection|
            pids << connection.select_value("SELECT pg_backend_pid()")
            case action
            when :rotate
              session.post "/account/api_tokens/#{token.id}/rotate", params: {api_token: {name: "replacement", scopes: ["apps:read"]}}, as: :json
            when :revoke
              session.delete "/account/api_tokens/#{token.id}", as: :json
            when :claim
              session.post "/account/api_tokens/claim", params: {token: secret}, as: :json
            end
            session.response
          end
        end
      end
      worker_pids = Timeout.timeout(10) { [pids.pop, pids.pop] }
      assert_equal 2, worker_pids.uniq.size
      refute_includes worker_pids, ApiToken.connection.select_value("SELECT pg_backend_pid()")
      Timeout.timeout(10) do
        loop do
          ApiToken.connection.execute("SELECT pg_stat_clear_snapshot()")
          waiting = ApiToken.connection.select_value("SELECT COUNT(*) FROM pg_stat_activity WHERE pid IN (#{worker_pids.map(&:to_i).join(",")}) AND wait_event_type = 'Lock'")
          break if waiting == 2
          threads.each { |thread| thread.value unless thread.alive? }
          Thread.pass
        end
      end
    end
    threads.map(&:value)
  ensure
    threads&.each { |thread| thread.join(15) || thread.kill }
  end
end
