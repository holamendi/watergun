require "test_helper"

class StorageMountEnqueueTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class FailingAdapter
    attr_reader :open_transactions

    def enqueue(job)
      @open_transactions = ActiveRecord::Base.connection.transaction_open?
      raise ActiveJob::EnqueueError, "queue unavailable"
    end

    def enqueue_at(job, timestamp)
      enqueue(job)
    end
  end

  test "storage jobs share the app concurrency semaphore with other server actions" do
    mount = apps(:domain_test_app).storage_mounts.build(container_path: "/app/concurrency")
    action = ServerActions::MountStorage.new(server: mount.server, actionable: mount)

    assert_equal RunServerActionJob.new(action).concurrency_key, StorageServerActionJob.new(action).concurrency_key
  end

  test "deferred ActiveJob failure is swallowed after records commit" do
    adapter = FailingAdapter.new
    original = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = adapter
    mount = apps(:domain_test_app).storage_mounts.create!(container_path: "/app/deferred")
    job = nil
    ServerAction.transaction do
      action = ServerActions::MountStorage.create!(server: mount.server, actionable: mount)
      job = RunServerActionJob.perform_later(action)
      assert job.successfully_enqueued?
      assert_nil adapter.open_transactions
    end
    assert_not job.successfully_enqueued?
    assert_instance_of ActiveJob::EnqueueError, job.enqueue_error
    assert_equal false, adapter.open_transactions
    assert mount.server_actions.queued_or_running.exists?
  ensure
    RunServerActionJob.queue_adapter = original
  end

  test "same database Solid Queue insertion is inside lifecycle transaction and rolls back with it" do
    original = StorageServerActionJob.queue_adapter
    StorageServerActionJob.queue_adapter = :solid_queue
    assert_same ApplicationRecord.connection_pool, SolidQueue::Record.connection_pool
    mount = apps(:domain_test_app).storage_mounts.new(container_path: "/app/atomic")
    assert_no_difference [-> { StorageMount.count }, -> { ServerAction.count }, -> { SolidQueue::Job.count }] do
      StorageMount.transaction do
        assert mount.save_and_mount
        action = mount.server_actions.last
        queued = SolidQueue::Job.where(class_name: "StorageServerActionJob").find_by!("arguments LIKE ?", "%#{action.to_global_id}%")
        assert queued.persisted?
        raise ActiveRecord::Rollback
      end
    end
    assert mount.new_record?
    assert_equal true, RunServerActionJob.enqueue_after_transaction_commit
    assert_equal false, StorageServerActionJob.enqueue_after_transaction_commit
  ensure
    StorageServerActionJob.queue_adapter = original
  end

  test "enqueue callback rejection rolls back rather than leaving an orphaned action" do
    callback = -> { throw :abort }
    StorageServerActionJob.set_callback(:enqueue, :before, callback)
    mount = apps(:domain_test_app).storage_mounts.new(container_path: "/app/aborted")
    assert_no_difference [-> { StorageMount.count }, -> { ServerAction.count }] do
      assert_raises(ActiveJob::EnqueueError) { mount.save_and_mount }
    end
  ensure
    StorageServerActionJob.skip_callback(:enqueue, :before, callback)
  end

  test "adapter enqueue errors roll back create resume and detach and allow retry" do
    app = apps(:domain_test_app)
    adapter = FailingAdapter.new
    # Configure both the inherited job and the storage-specific job if present.
    jobs = [RunServerActionJob]
    jobs << StorageServerActionJob if defined?(StorageServerActionJob)
    originals = jobs.to_h { |klass| [klass, klass.queue_adapter] }
    jobs.each { |klass| klass.queue_adapter = adapter }

    mount = app.storage_mounts.new(container_path: "/app/queue_failure")
    assert_no_difference [-> { StorageMount.count }, -> { ServerAction.count }] do
      assert_raises(ActiveJob::EnqueueError) { mount.save_and_mount }
    end
    assert mount.new_record?
    assert_equal true, adapter.open_transactions

    [:detached, :error, :detach_failed, :active].each do |status|
      retained = app.storage_mounts.create!(container_path: "/app/queue_#{status}", status: status)
      path = retained.host_path
      assert_no_difference -> { ServerAction.count } do
        assert_raises(ActiveJob::EnqueueError) do
          (status == :active) ? StorageMount::DestroyStorageMount.new(retained).destroy : retained.resume
        end
      end
      assert_equal status.to_s, retained.reload.status
      assert_equal path, retained.host_path
      assert_not retained.server_actions.queued_or_running.exists?
      jobs.each { |klass| klass.queue_adapter = :test }
      assert (status == :active) ? StorageMount::DestroyStorageMount.new(retained).destroy : retained.resume
      assert retained.server_actions.queued_or_running.exists?
      jobs.each { |klass| klass.queue_adapter = adapter }
    end
    jobs.each { |klass| klass.queue_adapter = :test }
    assert mount.save_and_mount
    assert mount.persisted?
  ensure
    originals&.each { |klass, original| klass.queue_adapter = original }
  end
end
