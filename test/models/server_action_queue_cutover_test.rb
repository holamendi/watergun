require "test_helper"

class ServerActionQueueCutoverTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  self.use_transactional_tests = false

  test "simultaneous deliveries atomically execute only one remote mutation" do
    app = apps(:domain_test_app)
    run = create_server_action_run("apps.restart", server: app.server, target: app)
    transport = mock("SSH transport")
    transport.expects(:exec!).once.with do |command, options|
      options[:status][:exit_code] = 0
      sleep 0.05
      command == Dokku::Ps::RestartCommand.new(app: app.dokku_id).cmd
    end
    transport.expects(:loop).at_least_once
    Net::SSH.expects(:start).once.yields(transport)
    threads = 2.times.map do
      Thread.new { RunServerActionJob.perform_now(run.id, run.resource_key) }
    end
    threads.each(&:value)
    assert run.reload.success?
    assert run.running_at
    assert run.finished_at
    assert app.reload.active?
    assert_equal 1, run.log.ssh_commands.size
  ensure
    threads&.each(&:join)
    run&.destroy!
  end

  test "Solid Queue serializes different targets on the same server" do
    original = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = :solid_queue
    before_ids = SolidQueue::Job.pluck(:id)
    app = apps(:domain_test_app)
    first = ServerAction::Enqueue.call(action: "apps.restart", target: app)
    second = ServerAction::Enqueue.call(action: "apps.remove_domain", target: domains(:domain_test_secondary))
    jobs = SolidQueue::Job.where(class_name: "RunServerActionJob").where.not(id: before_ids)
    assert_equal 2, jobs.count
    assert_equal 1, jobs.distinct.count(:concurrency_key)
    assert_equal 1, SolidQueue::ReadyExecution.where(job_id: jobs.select(:id)).count
    assert_equal 1, SolidQueue::BlockedExecution.where(job_id: jobs.select(:id)).count
    assert first.reload.enqueued_at
    assert second.reload.enqueued_at
  ensure
    SolidQueue::Job.where.not(id: before_ids || []).where(class_name: "RunServerActionJob").each(&:destroy!) if before_ids
    RunServerActionJob.queue_adapter = original
  end

  test "non destructive environment read completes through enqueue and Solid Queue execution" do
    original = RunServerActionJob.queue_adapter
    RunServerActionJob.queue_adapter = :solid_queue
    before_ids = SolidQueue::Job.pluck(:id)
    app = apps(:domain_test_app)
    mock_ssh_session(host: app.server.public_ip, user: SshKey::USER, port: app.server.ssh_port,
      private_key: app.server.ssh_key.private_key,
      commands: [{cmd: Dokku::Config::ExportCommand.new(app: app.dokku_id).cmd, stdout: [{name: "TEST_ONLY", value: "queue-read-value"}].to_json}])
    run = ServerAction::Enqueue.call(action: "apps.pull_env", target: app)
    worker = SolidQueue::Process.register(kind: "Worker", name: "cutover-test", pid: Process.pid)
    execution = SolidQueue::ReadyExecution.claim(["default"], 1, worker.id).sole
    execution.perform
    assert run.reload.success?
    assert run.finished_at
    assert_equal "queue-read-value", app.env_variables.find_by!(name: "TEST_ONLY").value
    refute_includes run.log.ssh_commands.to_json, "queue-read-value"
    assert_equal 1, run.log.ssh_commands.size
  ensure
    SolidQueue::Job.where.not(id: before_ids || []).where(class_name: "RunServerActionJob").each(&:destroy!) if before_ids
    worker&.destroy!
    run&.destroy!
    RunServerActionJob.queue_adapter = original
  end
end
