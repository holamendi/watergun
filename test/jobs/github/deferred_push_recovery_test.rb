require "test_helper"
require "timeout"

class Github::DeferredPushRecoveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # These cases prove committed event state, actual queue failure and independent
  # PostgreSQL deliveries. Transactional fixtures would conceal those boundaries.
  self.use_transactional_tests = false

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "push-recovery", status: :active)
    @app.server.update!(cpu_type: :x86)
    @app.create_github_repo!(account: @app.account, repo: "owner/push-recovery", branch: "main", webhook_deploy: true)
    @event = Github::Event.create!(installation: @app.account.github_installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {"ref" => "refs/heads/main", "after" => "b" * 40, "repository" => {"full_name" => "owner/push-recovery"}})
    commit = stub(sha: "b" * 40, author: nil, commit: stub(author: nil, message: "push"), html_url: "https://example.test/commit")
    Github::Installation.any_instance.stubs(:api_client).returns(stub(commit: commit))
    @adapter = Github::ProcessEventJob.queue_adapter
    @jobs = SolidQueue::Job.where(class_name: "Github::ProcessEventJob")
      .where("arguments::jsonb -> 'arguments' -> 0 ->> '_aj_globalid' = ?", @event.to_global_id.to_s)
  end

  teardown do
    Github::ProcessEventJob.queue_adapter = @adapter
    @jobs.destroy_all
    runs = ServerActionRun.where(target: @app).or(ServerActionRun.where(target: @app.deployments))
    ServerActionLog.where(server_action_run_id: runs.select(:id)).delete_all
    runs.delete_all
    @app.destroy!
    @event.destroy!
  end

  test "queue outage cannot lose a busy target and scheduler recovers only routed pending events" do
    ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    Github::ProcessEventJob.queue_adapter = :solid_queue
    connection = Github::Event.connection
    connection.execute(<<~SQL)
      CREATE FUNCTION reject_push_retry_test() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.class_name = 'Github::ProcessEventJob' THEN RAISE EXCEPTION 'test retry queue unavailable'; END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER reject_push_retry_test BEFORE INSERT ON solid_queue_jobs
      FOR EACH ROW EXECUTE FUNCTION reject_push_retry_test();
    SQL
    Github::ProcessEventJob.perform_now(@event)
    assert_equal [@app.id], @event.reload.pending_app_ids
    refute @event.processed?
    entered = Queue.new
    reader = Thread.new do
      Github::Event.connection_pool.with_connection do |other|
        entered << other.select_value("SELECT pg_backend_pid()")
        Github::Event.find(@event.id).pending_app_ids
      end
    end
    refute_equal connection.select_value("SELECT pg_backend_pid()"), Timeout.timeout(10) { entered.pop }
    assert reader.join(10)
    assert_equal [@app.id], reader.value
    connection.execute("DROP TRIGGER reject_push_retry_test ON solid_queue_jobs; DROP FUNCTION reject_push_retry_test()")
    Github::ProcessEventJob.recover_pending
    assert_equal 1, @jobs.count
    assert_equal @event.to_global_id.to_s, @jobs.sole.arguments.dig("arguments", 0, "_aj_globalid")
    assert_nil github_events(:push_event).reload.pending_app_ids, "legacy events are not automatically replayed"
  ensure
    connection&.execute("DROP TRIGGER IF EXISTS reject_push_retry_test ON solid_queue_jobs; DROP FUNCTION IF EXISTS reject_push_retry_test()")
    if reader&.alive?
      reader.kill
      reader.join(10)
    end
  end

  test "independent deliveries accept each event target exactly once" do
    entered = Queue.new
    workers = []
    @event.with_lock do
      owner = Github::Event.connection.select_value("SELECT pg_backend_pid()")
      workers = 2.times.map do
        Thread.new do
          Github::Event.connection_pool.with_connection do |connection|
            entered << connection.select_value("SELECT pg_backend_pid()")
            Github::ProcessEventJob.perform_now(Github::Event.find(@event.id))
          end
        end
      end
      pids = Timeout.timeout(10) { [entered.pop, entered.pop] }
      assert_equal 2, pids.uniq.size
      refute_includes pids, owner
      Timeout.timeout(10) do
        loop do
          Github::Event.connection.execute("SELECT pg_stat_clear_snapshot()")
          count = Github::Event.connection.select_value("SELECT count(*) FROM pg_stat_activity WHERE pid IN (#{pids.map(&:to_i).join(",")}) AND pg_blocking_pids(pid) && ARRAY[#{([owner] + pids).map(&:to_i).join(",")}]")
          break if count == 2
          workers.each { |worker| worker.value unless worker.alive? }
          Thread.pass
        end
      end
    end
    workers.each { |worker|
      assert worker.join(15)
      worker.value
    }
    assert @event.reload.processed?
    assert_empty @event.pending_app_ids
    assert_equal 1, @app.deployments.where(github_event: @event).count
    assert_equal 1, ServerActionRun.where(target: @app.deployments.where(github_event: @event)).count
  ensure
    workers.each do |worker|
      if worker.alive?
        worker.kill
        worker.join(10)
      end
    end
  end
end
