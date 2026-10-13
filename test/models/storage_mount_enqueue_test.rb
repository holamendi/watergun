require "test_helper"

class StorageMountEnqueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.use_transactional_tests = false

  class FailingAdapter
    def enqueue(job)
      raise ActiveJob::EnqueueError, "test-only queue unavailable"
    end

    def enqueue_at(job, timestamp)
      enqueue(job)
    end
  end

  test "different action targets on a server share a concurrency key" do
    app = apps(:domain_test_app)
    mount = app.storage_mounts.create!(container_path: "/app/concurrency")
    storage = ServerAction::Enqueue.build(action: "apps.mount_storage", target: mount)
    restart = ServerAction::Enqueue.build(action: "apps.restart", target: app)
    assert_equal storage.resource_key, restart.resource_key
    assert_equal RunServerActionJob.new(storage.id, storage.resource_key).concurrency_key,
      RunServerActionJob.new(restart.id, restart.resource_key).concurrency_key
  end

  test "after commit scheduling failure is surfaced and retained for explicit repair" do
    original = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = FailingAdapter.new
    mount = apps(:domain_test_app).storage_mounts.new(container_path: "/app/deferred")
    assert_raises(ActiveJob::EnqueueError) { mount.save_and_mount }
    assert mount.persisted?
    run = mount.server_action_runs.sole
    assert run.queued?
    assert_nil run.enqueued_at
    assert run.scheduling_failed_at
    refute_includes run.failure_message, "test-only queue unavailable"
    RunServerActionJob.queue_adapter = original
    assert_enqueued_with(job: RunServerActionJob, args: [run.id, run.resource_key]) { ServerAction::Enqueue.schedule(run) }
    assert run.reload.enqueued_at
    assert_nil run.scheduling_failed_at
    assert_raises(ArgumentError) { ServerAction::Enqueue.schedule(run) }
  ensure
    RunServerActionJob.queue_adapter = original
  end

  test "transaction rollback leaves no jobs or orphaned storage runs" do
    mount = apps(:domain_test_app).storage_mounts.new(container_path: "/app/atomic")
    assert_no_enqueued_jobs(only: RunServerActionJob) do
      assert_no_difference [-> { StorageMount.count }, -> { ServerActionRun.count }] do
        StorageMount.transaction do
          assert mount.save_and_mount
          assert mount.server_action_runs.sole.queued?
          raise ActiveRecord::Rollback
        end
      end
    end
    assert mount.new_record?
  end

  test "scheduling is deferred until surrounding transaction commits" do
    mount = apps(:domain_test_app).storage_mounts.new(container_path: "/app/after_commit")
    assert_enqueued_jobs 1, only: RunServerActionJob do
      StorageMount.transaction do
        assert_no_enqueued_jobs(only: RunServerActionJob) { assert mount.save_and_mount }
        assert_nil mount.server_action_runs.sole.enqueued_at
      end
    end
    assert mount.server_action_runs.sole.enqueued_at
  end

  test "callback rejection retains unscheduled lifecycle state and can be repaired" do
    callback = -> { throw :abort }
    RunServerActionJob.set_callback(:enqueue, :before, callback)
    mount = apps(:domain_test_app).storage_mounts.new(container_path: "/app/aborted")
    assert_raises(ActiveJob::EnqueueError) { mount.save_and_mount }
    assert mount.persisted?
    assert mount.server_action_runs.sole.scheduling_failed_at
  ensure
    RunServerActionJob.skip_callback(:enqueue, :before, callback)
  end
end
