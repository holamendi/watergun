require "test_helper"

class DependencyQueueProbeJob < ApplicationJob
  queue_as :dependency_probe

  def perform(project_id, name)
    Project.find(project_id).update!(name: name)
  end
end

class SolidQueueCompatibilityTest < ActiveSupport::TestCase
  test "the real queue claims executes and finalizes a serialized database job" do
    assert_same ApplicationRecord.connection_pool, SolidQueue::Record.connection_pool
    project = projects(:default)
    process = SolidQueue::Process.register(kind: "Worker", name: "dependency-test", pid: Process.pid, hostname: "localhost")
    refute SolidQueue::Batch.migrated?, "optional batch schema is not needed for existing jobs"
    active_job = DependencyQueueProbeJob.new(project.id, "Queue compatibility")
    job = ActiveJob::QueueAdapters::SolidQueueAdapter.new.enqueue(active_job)
    assert_equal job.id, active_job.provider_job_id
    claims = SolidQueue::ReadyExecution.claim(["dependency_probe"], 1, process.id)
    assert_equal [job.id], claims.map(&:job_id)
    assert_equal 0, SolidQueue::ReadyExecution.where(job_id: job.id).count
    claims.first.perform
    assert_equal "Queue compatibility", project.reload.name
    assert job.reload.finished_at
    assert_equal 0, SolidQueue::ClaimedExecution.where(job_id: job.id).count
    assert_equal 0, SolidQueue::FailedExecution.where(job_id: job.id).count
    assert_empty SolidQueue::ReadyExecution.claim(["dependency_probe"], 1, process.id)
  ensure
    process&.deregister
  end

  test "the real queue insert rolls back with the shared primary transaction" do
    before = SolidQueue::Job.count
    ApplicationRecord.transaction(requires_new: true) do
      ActiveJob::QueueAdapters::SolidQueueAdapter.new.enqueue(DependencyQueueProbeJob.new(projects(:default).id, "Never performed"))
      assert_equal before + 1, SolidQueue::Job.count
      raise ActiveRecord::Rollback
    end
    assert_equal before, SolidQueue::Job.count
  end
end
