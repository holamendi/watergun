require "test_helper"
require "timeout"

class ServerActionConcurrencyTest < ActiveSupport::TestCase
  # Transactional fixtures share a connection across threads, making session
  # advisory locks reentrant instead of exercising independent worker sessions.
  self.use_transactional_tests = false

  test "advisory locks allow independent apps on the same server to execute" do
    first = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:domain_test_app))
    second = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:smol_roda))
    assert_equal first.server_id, second.server_id
    assert_lock_scope first, second, blocked: false
  end

  test "advisory locks allow independent services on the same server to execute" do
    first = ServerAction::Enqueue.build(action: "services.restart", target: services(:postgres))
    second = ServerAction::Enqueue.build(action: "services.restart", target: services(:redis))
    assert_equal first.server_id, second.server_id
    assert_lock_scope first, second, blocked: false
  end

  test "deliveries for the same service share an advisory lock" do
    first = ServerAction::Enqueue.build(action: "services.restart", target: services(:postgres))
    second = ServerAction::Enqueue.build(action: "services.restart", target: services(:postgres))
    assert_lock_scope first, second, blocked: true
  end

  test "legacy and new deliveries for the same app share an advisory lock" do
    app = apps(:domain_test_app)
    first = ServerAction::Enqueue.build(action: "apps.restart", target: app)
    first.resource_key = "server:#{app.server_id}"
    second = ServerAction::Enqueue.build(action: "apps.remove_domain", target: domains(:domain_test_secondary))
    assert_lock_scope first, second, blocked: true
  end

  private

  def assert_lock_scope(first, second, blocked:)
    entered = Queue.new
    release = Queue.new
    pids = Queue.new
    first_runner = ServerAction::Runner.new(first)
    first_runner.define_singleton_method(:perform_claimed) do
      entered << :first
      release.pop
    end
    second_runner = ServerAction::Runner.new(second)
    second_runner.define_singleton_method(:perform_claimed) { entered << :second }

    first_thread = Thread.new do
      ServerActionRun.connection_pool.with_connection do |connection|
        pids << connection.select_value("SELECT pg_backend_pid()")
        first_runner.call
      end
    end
    assert_equal :first, Timeout.timeout(5) { entered.pop }
    first_pid = pids.pop
    second_thread = Thread.new do
      ServerActionRun.connection_pool.with_connection do |connection|
        pids << connection.select_value("SELECT pg_backend_pid()")
        second_runner.call
      end
    end
    second_pid = Timeout.timeout(5) { pids.pop }
    refute_equal first_pid, second_pid

    state = Timeout.timeout(5) do
      loop do
        break :second unless entered.empty?
        wait = ServerActionRun.connection.select_value("SELECT wait_event FROM pg_stat_activity WHERE pid = #{second_pid.to_i}")
        break :blocked if wait == "advisory"
        Thread.pass
      end
    end
    assert_equal blocked ? :blocked : :second, state
  ensure
    release << true if release
    [first_thread, second_thread].compact.each(&:value)
  end
end
