require "test_helper"
require "base64"
require "stringio"

class ServerActionExceptionBoundaryTest < ActiveSupport::TestCase
  test "secret bearing SSH exceptions stay inside the runner boundary through framework logging and queue storage" do
    app = apps(:smol_roda)
    run = create_server_action_run("apps.restart", server: app.server, target: app)
    secret = "test-only-github-token"
    encoded = Base64.strict_encode64("test-only-environment-value")
    original = IOError.new("could not execute command: git clone https://#{secret}@github.com/example/repo && echo #{encoded}")
    original.set_backtrace(["transport.rb:1:in `#{secret}'"])
    Server.any_instance.stubs(:ssh_session).raises(original)
    App.any_instance.expects(:error!).once.raises(IOError, "secondary-#{secret}")
    notices = []
    Honeybadger.stubs(:notify).with do |error, options|
      notices << [error, options]
      true
    end
    worker = SolidQueue::Process.register(kind: "Worker", name: "sanitized-action-test", pid: Process.pid)
    queued = SolidQueue::Job.enqueue(RunServerActionJob.new(run.id, run.resource_key).set(queue: "sanitized-action-test"))
    execution = SolidQueue::ReadyExecution.claim(["sanitized-action-test"], 1, worker.id).sole
    output = StringIO.new
    logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))

    ActiveJob::Base.stubs(:logger).returns(logger)
    error = assert_raises(StandardError) { execution.perform }

    refute_same original, error
    assert_nil error.cause
    assert_equal "RunServerActionJob::ExecutionError", error.class.name
    assert_equal "Server action execution failed", error.message
    stored = queued.reload.failed_execution
    assert stored
    assert run.reload.error?
    assert_match(/IOError/, run.failure_message)
    assert_equal 3, notices.size
    assert notices.all? { |notice, options| notice.cause.nil? }
    assert_equal 2, notices.count { |notice, options| options[:context][:server_action_run_id] == run.id }
    assert_same error, notices.last.first
    assert_equal RunServerActionJob, notices.last.last[:context][:job_class]
    assert_match(/Error performing RunServerActionJob/, output.string)
    [error.full_message, output.string, stored.error.to_json, notices.map { |notice, options| notice.full_message }.join].each do |text|
      refute_includes text, secret
      refute_includes text, encoded
      refute_includes text, "test-only-environment-value"
      refute_includes text, "could not execute command"
    end
    assert_nil queued.finished_at
    refute SolidQueue::ReadyExecution.exists?(job: queued)
    refute SolidQueue::ScheduledExecution.exists?(job: queued)
  end
end
