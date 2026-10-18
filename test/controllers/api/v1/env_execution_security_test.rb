require "test_helper"
require "stringio"

class Api::V1::EnvExecutionSecurityTest < ActionDispatch::IntegrationTest
  include SshTestHelper

  # Real claimed queue jobs and committed desired state must survive failures.
  self.use_transactional_tests = false

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "env-security", status: :active)
    @app.server.update!(status: :active)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["env:write", "operations:read"])
    @secret = @token.token
    @value = "worker-environment-sentinel"
    @encoded = Base64.strict_encode64(@value)
  end

  teardown do
    @worker&.destroy!
    @job&.destroy!
    runs = ServerActionRun.where(target: @app)
    ServerActionLog.where(server_action_run_id: runs.select(:id)).delete_all
    runs.delete_all
    @app.destroy!
    ApiTokenAudit.where(api_token_id: @token.id).delete_all
    @token.destroy!
  end

  test "actual claimed job failure persists no values in diagnostics telemetry instrumentation or cause chains" do
    accept
    run = accepted_run
    transport = mock("transport")
    transport.expects(:exec!).with do |command, **_options|
      assert_includes command, @encoded
      refute ActiveRecord::Base.connection.transaction_open?
      true
    end.raises(IOError, "rejected #{@value} #{@encoded}")
    Net::SSH.expects(:start).yields(transport)
    observe do |output, events, notices|
      @worker = SolidQueue::Process.register(kind: "Worker", name: "env-boundary", pid: Process.pid)
      @job = SolidQueue::Job.enqueue(RunServerActionJob.new(run.id, run.resource_key).set(queue: "env-boundary"))
      claimed = SolidQueue::ReadyExecution.claim(["env-boundary"], 1, @worker.id).sole
      error = assert_raises(RunServerActionJob::ExecutionError) { claimed.perform }
      assert_nil error.cause
      assert run.reload.outcome_uncertain?
      assert_equal "outcome_unknown", run.public_error_code
      assert @job.reload.failed_execution
      refute SolidQueue::ReadyExecution.exists?(job: @job)
      refute SolidQueue::ScheduledExecution.exists?(job: @job)
      assert notices.any?
      assert notices.all? { |exception, _| exception.cause.nil? }
      data = [error.full_message, output.string, events.join, notices.map { |exception, options| [exception.full_message, options] }.inspect,
        @job.failed_execution.error.to_json, run.log.reload.attributes.to_json, run.attributes.except("payload").to_json,
        ApiTokenAudit.all.map(&:attributes).to_json].join
      assert_private data
    end
    Net::SSH.expects(:start).never
    ServerAction::Recovery.call
    assert run.reload.outcome_uncertain?
    put "/api/v1/apps/#{@app.id}/env", params: {mode: "merge", values: {GREETING: "another"}}, as: :json,
      headers: {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => "new-after-unknown"}
    assert_response :conflict
  end

  test "malformed remote export stays secret through actual pull job persistence and failure boundary" do
    accept
    run = accepted_run
    mock_ssh_session(host: @app.server.public_ip, user: SshKey::USER, port: @app.server.ssh_port, private_key: @app.server.ssh_key.private_key,
      commands: [{cmd: Dokku::Config::SetCommand.new(app: @app.dokku_id, env: {"GREETING" => @value}).cmd, stdout: @value, stderr: @encoded}])
    RunServerActionJob.perform_now(run.id, run.resource_key)
    pull = ServerActionRun.where(target: @app, action_key: "apps.pull_env").sole
    ["not-json #{@value} #{@encoded}", {"unexpected" => @value}.to_json].each do |output|
      pull.update!(status: :queued, remote_completed_at: nil)
      transport = mock("export transport")
      transport.expects(:exec!).with do |command, options|
        assert_equal "dokku config:export #{@app.dokku_id} --format=json-list", command
        options[:status][:exit_code] = 0
        true
      end.multiple_yields([nil, :stdout, output], [nil, :stderr, @value])
      Net::SSH.expects(:start).yields(transport)
      observe do |logs, events, notices|
        error = assert_raises(RunServerActionJob::ExecutionError) { RunServerActionJob.perform_now(pull.id, pull.resource_key) }
        assert_nil error.cause
        assert pull.reload.error?
        assert_private [error.full_message, logs.string, events.join, pull.log.reload.attributes.to_json,
          notices.map { |exception, options| [exception.full_message, options] }.inspect, pull.failure_message].join
      end
    end
    assert_equal @value, @app.env_variables.kept.find_by!(name: "GREETING").value
  end

  test "revoked accepted token fails before SSH and leaves encrypted desired state inspectable" do
    accept
    run = accepted_run
    @token.update!(revoked_at: Time.current)
    Net::SSH.expects(:start).never
    error = assert_raises(RunServerActionJob::ExecutionError) { RunServerActionJob.perform_now(run.id, run.resource_key) }
    assert_nil error.cause
    assert_equal "authorization_failed", run.reload.public_error_code
    refute run.outcome_uncertain?
    raw = EnvVariable.connection.select_value("SELECT value FROM env_variables WHERE app_id = #{@app.id.to_i} AND name = 'GREETING'")
    assert_private raw
    assert_equal @value, @app.env_variables.kept.find_by!(name: "GREETING").value
  end

  private

  def accept
    put "/api/v1/apps/#{@app.id}/env", params: {mode: "merge", values: {GREETING: @value}}, as: :json,
      headers: {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => "worker"}
    assert_response :accepted
    assert_private response.body
  end

  def accepted_run = ServerActionRun.find(json_response.dig("operation", "id"))

  def assert_private(text)
    [@value, @encoded, @secret].each { |secret| refute_includes text, secret }
  end

  def observe
    output = StringIO.new
    old_rails, old_record, old_job = Rails.logger, ActiveRecord::Base.logger, ActiveJob::Base.logger
    Rails.logger = ActiveRecord::Base.logger = ActiveJob::Base.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))
    events, notices = [], []
    subscriber = ActiveSupport::Notifications.subscribe(/active_job/) do |*args|
      event = args.last
      events << [event[:exception], event[:exception_object]&.full_message].inspect
    end
    Honeybadger.stubs(:notify).with do |error, options|
      notices << [error, options]
      true
    end
    yield output, events, notices
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    Rails.logger, ActiveRecord::Base.logger, ActiveJob::Base.logger = old_rails, old_record, old_job
  end
end
