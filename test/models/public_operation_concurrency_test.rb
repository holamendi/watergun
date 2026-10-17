require "test_helper"
require "timeout"

class PublicOperationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @app = apps(:domain_test_app)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write", "operations:read"])
  end

  teardown do
    ServerActionLog.where(server_action_run_id: ServerActionRun.where.not(idempotency_digest: nil).select(:id)).delete_all
    ServerActionRun.where.not(idempotency_digest: nil).delete_all
    ServerActionRun.where(target: @app).where.not(id: ActiveRecord::FixtureSet.identify(:deploy_running)).delete_all
    ApiTokenAudit.delete_all
    ApiToken.delete_all
  end

  test "independent connections accept one canonical duplicate and conflict for changed payload" do
    [false, true].each do |different|
      key = different ? "different-concurrent" : "same-concurrent"
      results = contend(@token) do |index|
        accept(key: key, request: {value: (different && index == 1) ? "two" : "one"})
      rescue ServerAction::Accept::Error => error
        error.code
      end
      if different
        assert_equal 1, results.count("idempotency_conflict")
        assert_equal 1, results.count { |result| result.is_a?(ServerActionRun) }
      else
        assert_equal 1, results.map(&:id).uniq.size
      end
      ServerActionRun.where(target: @app).update_all(status: :success, finished_at: Time.current)
    end
  end

  test "a request authenticated before revocation cannot accept or replay after waiting for the token lock" do
    original = accept
    secret = @token.token
    stale = ApiToken.authenticate(secret)
    results = contend(@token, before_release: -> { @token.update!(revoked_at: Time.current) }) do
      accept(token: stale)
    rescue ServerAction::Accept::Error => error
      error.code
    end
    assert_equal ["unauthorized", "unauthorized"], results
    assert_equal 1, ServerActionRun.where(id: original.id).count
  end

  test "UI acceptance races use distinct connections and leave exactly one operation" do
    results = contend(@app) do
      ServerAction::Enqueue.call(action: "apps.restart", target: App.find(@app.id))
    rescue ServerAction::Conflict::Error
      :conflict
    end
    assert_equal 1, results.count(:conflict)
    assert_equal 1, results.count { |result| result.is_a?(ServerActionRun) }
  end

  test "live running resource is not recovered while its real worker advisory lock is held" do
    run = accept
    run.update!(status: :running, running_at: Time.current)
    entered, release = Queue.new, Queue.new
    thread = Thread.new do
      ServerActionRun.connection_pool.with_connection do |connection|
        key = Digest::SHA256.digest(run.resource_key).unpack1("q>")
        connection.execute("SELECT pg_advisory_lock(#{key})")
        entered << connection.select_value("SELECT pg_backend_pid()")
        release.pop
        connection.execute("SELECT pg_advisory_unlock(#{key})")
      end
    end
    pid = Timeout.timeout(10) { entered.pop }
    refute_equal pid, ServerActionRun.connection.select_value("SELECT pg_backend_pid()")
    ServerAction::Recovery.recover(run)
    assert run.reload.running?
  ensure
    release << true if release
    thread&.value
  end

  private

  def accept(key: "concurrent-key", request: {}, token: @token)
    ServerAction::Accept.call(token: token.clone, endpoint: "restart", target: App.find(@app.id), key: key,
      request: request, request_id: "concurrency-request", scope: "apps:write") do
      ServerAction::Enqueue.call(action: "apps.restart", target: App.find(@app.id))
    end
  end

  def contend(record, before_release: nil)
    pids = Queue.new
    threads = []
    record.with_lock do
      threads = 2.times.map do |index|
        Thread.new do
          ServerActionRun.connection_pool.with_connection do |connection|
            pids << connection.select_value("SELECT pg_backend_pid()")
            yield index
          end
        end
      end
      workers = Timeout.timeout(10) { [pids.pop, pids.pop] }
      assert_equal 2, workers.uniq.size
      refute_includes workers, ServerActionRun.connection.select_value("SELECT pg_backend_pid()")
      Timeout.timeout(10) do
        loop do
          ServerActionRun.connection.execute("SELECT pg_stat_clear_snapshot()")
          waiting = ServerActionRun.connection.select_value("SELECT COUNT(*) FROM pg_stat_activity WHERE pid IN (#{workers.map(&:to_i).join(",")}) AND wait_event_type = 'Lock'")
          break if waiting == 2
          threads.each { |thread| thread.value unless thread.alive? }
          Thread.pass
        end
      end
      before_release&.call
    end
    threads.map(&:value)
  ensure
    threads&.each { |thread| thread.join(15) || thread.kill }
  end
end
