require "test_helper"

class SharedAppDispatchTest < ActiveSupport::TestCase
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

  teardown do
    RunServerActionJob.queue_adapter = @original_adapter if @original_adapter
    ServerActionRun.where(id: @run_ids || []).destroy_all
    @variable&.destroy!
    @deployment&.destroy!
  end

  test "shared env acceptance surfaces post-commit queue failure and retains an inspectable run" do
    @original_adapter = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = FailingAdapter.new
    app = apps(:smol_roda)
    @variable = app.env_variables.new(name: "SHARED_QUEUE", value: "queue-secret-only")
    assert_raises(ActiveJob::EnqueueError) { EnvVariable::CreateEnvVariable.new(@variable).save }
    assert @variable.reload.persisted?
    run = app.server_action_runs.where(action_key: "apps.update_env").order(:id).last
    @run_ids = [run.id]
    assert run.queued?
    assert run.scheduling_failed_at
    assert_nil run.enqueued_at
    refute_includes run.failure_message, "queue-secret-only"
    refute_includes run.failure_message, "test-only queue unavailable"

    RunServerActionJob.queue_adapter = @original_adapter
    assert_enqueued_with(job: RunServerActionJob, args: [run.id, run.resource_key]) do
      ServerAction::Enqueue.schedule(run)
    end
    assert run.reload.enqueued_at
  end

  test "shared deployment acceptance retains its run on post-commit queue failure" do
    @original_adapter = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = FailingAdapter.new
    app = apps(:smol_roda)
    VCR.use_cassette("github/valid_commit") do
      assert_raises(ActiveJob::EnqueueError) { Deployment::CreateDeployment.new(app: app).save! }
    end
    @deployment = app.deployments.order(:id).last
    run = @deployment.server_action_run
    @run_ids = [run.id]
    assert run.queued?
    assert run.scheduling_failed_at
    assert_nil run.enqueued_at
    assert @deployment.pending?
  end
end
