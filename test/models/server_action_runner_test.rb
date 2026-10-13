require "test_helper"

class ServerActionRunnerTest < ActiveSupport::TestCase
  test "advisory unlock failure cannot replace a primary execution exception" do
    run = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:smol_roda))
    runner = ServerAction::Runner.new(run)
    primary = IOError.new("test-only-primary-secret")
    runner.stubs(:perform_claimed).raises(primary)
    connection = mock("advisory connection")
    connection.expects(:execute).with(regexp_matches(/pg_advisory_lock/))
    connection.expects(:execute).with(regexp_matches(/pg_advisory_unlock/)).raises(IOError, "secondary-secret")
    ServerActionRun.connection_pool.expects(:with_connection).yields(connection)
    assert_same primary, assert_raises(IOError) { runner.call }
  end

  test "only queued cancellation is allowed and cancelled deliveries never mutate" do
    run = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:smol_roda))
    run.save!
    assert run.cancel!
    assert run.reload.cancelled?
    assert run.finished_at
    Net::SSH.expects(:start).never
    assert_equal run, ServerAction::Runner.new(run).call
    run.update!(status: :running, finished_at: nil)
    refute run.cancel!
    assert run.reload.running?
  end

  test "ownership and snapshotted identifier changes are revalidated before SSH" do
    app = apps(:smol_roda)
    run = ServerAction::Enqueue.build(action: "apps.restart", target: app)
    run.save!
    app.update_columns(dokku_id: "changed-test-only")
    Net::SSH.expects(:start).never
    assert_raises(ArgumentError) { ServerAction::Runner.new(run).call }
    assert run.reload.error?
    assert app.reload.pending?
  end
  test "duplicate running and terminal deliveries never open SSH" do
    app = apps(:smol_roda)
    run = ServerAction::Enqueue.build(action: "apps.restart", target: app)
    run.save!
    Net::SSH.expects(:start).never
    %w[running success failure error cancelled].each do |status|
      run.update!(status: status)
      assert_equal run, ServerAction::Runner.new(run).call
    end
  end

  test "missing target records sanitized error before SSH" do
    run = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:smol_roda))
    run.save!
    run.update_columns(target_id: nil)
    Net::SSH.expects(:start).never
    assert_raises(ArgumentError) { ServerAction::Runner.new(run).call }
    assert run.reload.error?
    assert run.finished_at
  end

  test "unknown historical key is recorded rather than stranded queued" do
    run = ServerAction::Enqueue.build(action: "apps.restart", target: apps(:smol_roda))
    run.save!
    run.update_columns(action_key: "unknown.secret-bearing-value")
    Net::SSH.expects(:start).never
    assert_raises(KeyError) { ServerAction::Runner.new(run).call }
    assert run.reload.error?
    refute_includes run.failure_message, "secret-bearing-value"
  end
end
