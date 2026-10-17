require "test_helper"
require "timeout"

class Api::V1::EnvConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @app = apps(:domain_test_app)
    @app.env_variables.destroy_all
    ServerActionRun.where(target: @app).delete_all
    @app.update!(status: :active, deployed_at: Time.current, pending_restart: false)
    @app.server.update!(status: :active)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["env:write", "apps:write"])
    @secret = @token.token
    @path = "/api/v1/apps/#{@app.id}/env"
    @body = {mode: "merge", values: {GREETING: "concurrent-value"}}
  end

  teardown do
    @app.env_variables.destroy_all
    ServerActionLog.delete_all
    ApiTokenAudit.delete_all
    ApiToken.delete_all
    Session.delete_all
  end

  test "independent HTTP connections canonical duplicates accept one batch while different input has one conflict" do
    responses = compete([:put, @path, @body, "same"], [:put, @path, @body, "same"])
    assert_equal [202, 202], responses.map(&:status)
    assert_equal 1, responses.map { |response| JSON.parse(response.body).dig("operation", "id") }.uniq.size
    assert_equal 1, ServerActionRun.where(api_token_id: @token.id).count
    assert_equal 1, @app.env_variables.kept.count
    responses = compete([:put, @path, @body, "same"], [:put, @path, @body.deep_merge(values: {GREETING: "different"}), "same"])
    assert_equal [202, 409], responses.map(&:status).sort
    assert_equal "idempotency_conflict", JSON.parse(responses.find { |response| response.status == 409 }.body).dig("error", "code")
    assert_equal 1, ServerActionRun.where(api_token_id: @token.id).count
  end

  test "HTTP env and API restart compete for the same app with only one accepted operation" do
    responses = compete([:put, @path, @body, "env"], [:post, "/api/v1/apps/#{@app.id}/restarts", nil, "restart"])
    assert_equal [202, 409], responses.map(&:status).sort
    assert_equal 1, ServerActionRun.where(api_token_id: @token.id).count
    assert_equal "operation_conflict", JSON.parse(responses.find { |response| response.status == 409 }.body).dig("error", "code")
  end

  test "in flight acceptance rechecks token after a real lock wait and rolls back all env changes" do
    pids = Queue.new
    thread = nil
    @token.with_lock do
      thread = request_thread([:put, @path, @body, "stale"], pids)
      wait_for_locks([Timeout.timeout(10) { pids.pop }])
      @token.update!(revoked_at: Time.current)
    end
    response = Timeout.timeout(15) { thread.value }
    assert_equal 401, response.status
    assert_empty @app.env_variables.kept
    assert_equal 0, ServerActionRun.where(api_token_id: @token.id).count
  ensure
    thread&.join(15) || thread&.kill
  end

  test "UI env mutation waiting on app lock loses to committed API batch without partial local changes" do
    variable = @app.env_variables.create!(name: "UI_VALUE", value: "before")
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post "/session", params: {session: {email: users(:bobby).email, password: "abc123456"}}
    assert session.cookies[:session_token].present?
    pids = Queue.new
    thread = nil
    App.transaction do
      @app.lock!
      thread = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          pids << connection.select_value("SELECT pg_backend_pid()")
          session.patch "/projects/#{@app.project_id}/apps/#{@app.id}/env/#{variable.id}",
            params: {env_variable: {name: "RENAMED", value: "ui-new"}}, as: :turbo_stream
          session.response
        end
      end
      wait_for_locks([Timeout.timeout(10) { pids.pop }])
      Current.set(account: @app.account, user: users(:bobby), source: :api_v1) do
        command = EnvVariable::WriteEnvVariables.new(app: @app, mode: "merge", values: {"API_VALUE" => "api-new"})
        assert command.save
      end
    end
    assert_equal 409, Timeout.timeout(15) { thread.value }.status
    assert_equal "UI_VALUE", variable.reload.name
    assert_equal "before", variable.value
    assert_equal ["API_VALUE", "UI_VALUE"], @app.env_variables.kept.order(:name).pluck(:name)
  ensure
    thread&.join(15) || thread&.kill
  end

  private

  def compete(*requests)
    pids = Queue.new
    threads = []
    @token.with_lock do
      threads = requests.map { |request| request_thread(request, pids) }
      worker_pids = Timeout.timeout(10) { requests.map { pids.pop } }
      assert_equal requests.length, worker_pids.uniq.length
      wait_for_locks(worker_pids)
    end
    Timeout.timeout(15) { threads.map(&:value) }
  ensure
    threads.each { |thread| thread.join(15) || thread.kill }
  end

  def request_thread(request, pids)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        pids << connection.select_value("SELECT pg_backend_pid()")
        session = ActionDispatch::Integration::Session.new(Rails.application)
        method, path, body, key = request
        args = {headers: {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key}}
        if body
          args[:params] = body
          args[:as] = :json
        end
        session.public_send(method, path, **args)
        session.response
      end
    end
  end

  def wait_for_locks(pids)
    refute_includes pids, ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
    Timeout.timeout(10) do
      loop do
        ActiveRecord::Base.connection.execute("SELECT pg_stat_clear_snapshot()")
        count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM pg_stat_activity WHERE pid IN (#{pids.map(&:to_i).join(",")}) AND wait_event_type = 'Lock'")
        break if count == pids.size
        Thread.pass
      end
    end
  end
end
