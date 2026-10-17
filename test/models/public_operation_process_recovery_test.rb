require "test_helper"
require "timeout"

class PublicOperationProcessRecoveryTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @app = apps(:domain_test_app)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write"])
    @old_adapter = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = :solid_queue
  end

  teardown do
    RunServerActionJob.queue_adapter = @old_adapter
    connection = ServerActionRun.connection
    connection.execute("DROP TRIGGER IF EXISTS public_operation_queue_unavailable ON solid_queue_jobs")
    connection.execute("DROP FUNCTION IF EXISTS public_operation_queue_unavailable()")
    SolidQueue::Job.where(class_name: "RunServerActionJob").destroy_all
    SolidQueue::Process.where(name: "public-operation-crash-#{@app.id}").destroy_all
    runs = ServerActionRun.where(operation_app_id: @app.id)
    ServerActionLog.where(server_action_run_id: runs.select(:id)).delete_all
    runs.delete_all
    ApiTokenAudit.delete_all
    ApiToken.delete_all
  end

  test "real queue insert failure preserves committed acceptance and a new process recovers it" do
    assert_same ServerActionRun.connection_pool, SolidQueue::Record.connection_pool
    connection = ServerActionRun.connection
    connection.execute(<<~SQL)
      CREATE FUNCTION public_operation_queue_unavailable() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.class_name = 'RunServerActionJob' THEN RAISE EXCEPTION 'test queue unavailable'; END IF;
        RETURN NEW;
      END $$
    SQL
    connection.execute("CREATE TRIGGER public_operation_queue_unavailable BEFORE INSERT ON solid_queue_jobs FOR EACH ROW EXECUTE FUNCTION public_operation_queue_unavailable()")
    run = accept
    assert run.reload.dispatch_pending_at
    assert_nil run.enqueued_at
    assert_equal 0, SolidQueue::Job.where(class_name: "RunServerActionJob").count
    connection.execute("DROP TRIGGER public_operation_queue_unavailable ON solid_queue_jobs")
    in_process do |pipe|
      ServerAction::Recovery.recover(ServerActionRun.find(run.id))
      pipe.puts("recovered")
    end
    assert run.reload.enqueued_at
    assert_nil run.dispatch_pending_at
    assert_equal 1, SolidQueue::Job.where(class_name: "RunServerActionJob").count
    assert_equal run.id, accept.id
  end

  test "worker death after remote send is outcome unknown with retained exclusion and no replay on restart" do
    run = accept
    in_process(kill: true) do |pipe|
      transport = Object.new
      transport.define_singleton_method(:commands) { [] }
      transport.define_singleton_method(:execute!) do |_command|
        pipe.puts("remote-sent")
        sleep 60
      end
      Server.any_instance.stubs(:ssh_session).yields(transport)
      worker = SolidQueue::Process.register(kind: "Worker", name: "public-operation-crash-#{@app.id}", pid: Process.pid)
      execution = SolidQueue::ReadyExecution.claim(["default"], 1, worker.id).sole
      execution.perform
    end
    assert run.reload.running?
    assert_nil run.remote_completed_at
    in_process do |pipe|
      ServerAction::Recovery.recover(ServerActionRun.find(run.id))
      RunServerActionJob.perform_now(run.id, run.resource_key)
      pipe.puts("recovered-without-ssh")
    end
    assert run.reload.error?
    assert run.outcome_uncertain?
    assert_equal "outcome_unknown", run.public_operation.dig(:error, :code)
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.destroy", target: @app) }
    assert_equal run.id, accept.id
  end

  test "worker death after persisted remote completion recovers success without replay" do
    run = accept
    in_process(kill: true) do |pipe|
      action = ServerActions::RestartApp.new(ServerActionRun.find(run.id))
      action.define_singleton_method(:execute!) { |_ssh| }
      action.define_singleton_method(:succeeded!) {
        pipe.puts("remote-completed")
        sleep 60
      }
      ServerAction::Registry.stubs(:build).returns(action)
      Server.any_instance.stubs(:ssh_session).yields(stub(commands: []))
      RunServerActionJob.perform_now(run.id, run.resource_key)
    end
    assert run.reload.running?
    assert run.remote_completed_at
    ServerAction::Recovery.recover(run)
    assert run.reload.success?
    refute run.outcome_uncertain?
    assert_equal "succeeded", run.public_operation.fetch(:status)
  end

  test "after commit notification failure cannot hide committed acceptance or lose dispatch" do
    ServerActionRun.any_instance.stubs(:broadcast_action_later_to).raises(IOError, "private-notification")
    run = accept
    assert run.reload.persisted?
    assert run.enqueued_at || run.dispatch_pending_at
    assert_equal run.id, accept.id
  end

  test "acceptance refuses an enclosing caller transaction which could roll back a returned result" do
    ServerActionRun.transaction do
      assert_raises(ArgumentError) { accept }
      assert_equal 0, ServerActionRun.where(operation_app_id: @app.id).count
    end
  end

  test "dispatcher death between real queue insertion and bookkeeping rolls back both and recovers unsent work" do
    RunServerActionJob.any_instance.stubs(:enqueue).raises(ActiveJob::EnqueueError)
    run = accept
    RunServerActionJob.any_instance.unstub(:enqueue)
    in_process(kill: true) do |pipe|
      SolidQueue::Job.singleton_class.prepend(Module.new do
        define_method(:enqueue) do |*arguments|
          result = super(*arguments)
          pipe.puts("queue-inserted-uncommitted")
          sleep 60
          result
        end
      end)
      ServerAction::Enqueue.schedule(ServerActionRun.find(run.id))
    end
    assert run.reload.queued?
    assert run.dispatch_pending_at
    assert_nil run.enqueued_at
    assert_equal 0, SolidQueue::Job.where(class_name: "RunServerActionJob").count
    ServerAction::Recovery.recover(run)
    assert run.reload.enqueued_at
    assert_equal 1, SolidQueue::Job.where(class_name: "RunServerActionJob").count
  end

  private

  def accept
    ServerAction::Accept.call(token: @token, endpoint: "restart", target: @app, key: "process-key",
      request: {}, request_id: "process-request", scope: "apps:write") do
      ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    end
  end

  def in_process(kill: false)
    # No inherited PostgreSQL sockets: each fork opens a real independent DB session.
    ActiveRecord::Base.connection_handler.clear_all_connections!
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      writer.sync = true
      begin
        yield writer
        exit! 0
      rescue => error
        writer.puts("child-error:#{error.class}")
        exit! 1
      end
    end
    writer.close
    message = Timeout.timeout(15) { reader.gets }
    refute_nil message
    refute_match(/child-error/, message)
    if kill
      Process.kill("KILL", pid)
      _, status = Process.wait2(pid)
      assert status.signaled?
      assert_equal Signal.list.fetch("KILL"), status.termsig
    else
      _, status = Process.wait2(pid)
      assert status.success?, message
    end
  ensure
    reader&.close
    writer&.close unless writer&.closed?
    if pid
      begin
        Process.kill("KILL", pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
      end
    end
  end
end
