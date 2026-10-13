require "test_helper"

class ServerActionEnqueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "secondary scheduling bookkeeping cannot replace the primary enqueue exception" do
    run = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:smol_roda))
    run.save!
    original = ActiveJob::EnqueueError.new("test-only-primary-secret")
    RunServerActionJob.any_instance.stubs(:enqueue).raises(original)
    run.stubs(:update_columns).raises(IOError, "secondary-secret")
    assert_same original, assert_raises(ActiveJob::EnqueueError) { ServerAction::Enqueue.schedule(run) }
  end

  test "unknown keys and class arguments are rejected before persistence queueing or SSH" do
    Net::SSH.expects(:start).never
    ["unknown.action", "ServerActions::RestartApp", :"apps.restart", nil, Class.new, ServerActions::RestartApp].each do |action|
      assert_no_difference "ServerActionRun.count" do
        assert_no_enqueued_jobs do
          assert_raises(ArgumentError) { ServerAction::Enqueue.build(action: action, target: apps(:smol_roda)) }
          assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: action, target: apps(:smol_roda)) }
        end
      end
    end
  end
  test "string caller API encrypts every payload and queues only IDs with per server key" do
    app = apps(:smol_roda)
    run = nil
    assert_enqueued_with(job: RunServerActionJob, args: ->(args) { args == [run.id, "server:#{app.server_id}"] }) do
      run = ServerAction::Enqueue.call(action: "apps.restart", target: app, payload: {note: "private-value"})
    end
    assert_equal "apps.restart", run.action_key
    assert_equal app, run.target
    assert_equal "private-value", run.reload.payload.fetch("note")
    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{run.id}")
    refute_includes raw, "private-value"
    refute_includes raw, app.dokku_id
    assert run.enqueued_at
  end
end
