require "test_helper"
require "timeout"

class PublicOperationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @app = apps(:domain_test_app)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write", "operations:read"])
  end

  teardown do
    EnvVariable.delete_all
    ServerActionLog.where(server_action_run_id: ServerActionRun.where.not(idempotency_digest: nil).select(:id)).delete_all
    ServerActionRun.where.not(idempotency_digest: nil).delete_all
    ServerActionRun.where(target: @app).where.not(id: ActiveRecord::FixtureSet.identify(:deploy_running)).delete_all
    ApiTokenAudit.delete_all
    ApiToken.delete_all
  end

  test "independent connections accept one canonical duplicate and conflict for changed payload" do
    [false, true].each do |different|
      key = different ? "different-concurrent" : "same-concurrent"
      results = contend(@token) do |index|
        accept(key: key, request: {value: (different && index == 1) ? "two" : "one"})
      rescue ServerAction::Accept::Error => error
        error.code
      end
      if different
        assert_equal 1, results.count("idempotency_conflict")
        assert_equal 1, results.count { |result| result.is_a?(ServerActionRun) }
      else
        assert_equal 1, results.map(&:id).uniq.size
      end
      ServerActionRun.where(target: @app).update_all(status: :success, finished_at: Time.current)
    end
  end

  test "a request authenticated before revocation cannot accept or replay after waiting for the token lock" do
    original = accept
    secret = @token.token
    stale = ApiToken.authenticate(secret)
    results = contend(@token, before_release: -> { @token.update!(revoked_at: Time.current) }) do
      accept(token: stale)
    rescue ServerAction::Accept::Error => error
      error.code
    end
    assert_equal ["unauthorized", "unauthorized"], results
    assert_equal 1, ServerActionRun.where(id: original.id).count
  end

  test "in flight membership removal and ownership changes reject before domain mutation" do
    results = contend(@token, before_release: -> { Membership.where(user_id: @token.user_id, account_id: @token.account_id).delete_all }) do
      accept
    rescue ServerAction::Accept::Error => error
      error.code
    end
    assert_equal ["unauthorized", "unauthorized"], results
    Membership.create!(user_id: @token.user_id, account_id: @token.account_id)
    results = contend(@app, before_release: -> { @app.update_columns(account_id: accounts(:other).id) }) do
      accept
    rescue ServerAction::Accept::Error => error
      error.code
    end
    assert_equal ["not_found", "not_found"], results
    assert_empty ServerActionRun.where(api_token_id: @token.id)
  ensure
    @app.update_columns(account_id: @token.account_id)
  end

  test "UI acceptance races use distinct connections and leave exactly one operation" do
    results = contend(@app) do
      ServerAction::Enqueue.call(action: "apps.restart", target: App.find(@app.id))
    rescue ServerAction::Conflict::Error
      :conflict
    end
    assert_equal 1, results.count(:conflict)
    assert_equal 1, results.count { |result| result.is_a?(ServerActionRun) }
  end

  test "project deletion races atomically with app acceptance on independent connections" do
    project = Project.create!(server: @app.server, account: @app.account, name: "project-race")
    @app = project.apps.create!(server: project.server, name: "app-race")
    results = contend(project) do |index|
      (index == 0) ? accept : Project::DestroyProject.new(Project.find(project.id)).destroy
    rescue ServerAction::Accept::Error, ServerAction::Conflict::Error => error
      error.is_a?(ServerAction::Accept::Error) ? error.code : "operation_conflict"
    end
    assert_equal 1, results.count { |result| result.is_a?(ServerActionRun) }
    assert_equal 1, results.count { |result| %w[not_found operation_conflict].include?(result) }
    winner = results.find { |result| result.is_a?(ServerActionRun) }
    assert_equal winner.action_key == "projects.destroy", project.reload.discarded?
  end

  test "API and UI env preparation use consistent locks without deadlock or duplicate acceptance" do
    variable = @app.env_variables.create!(name: "CONCURRENT_ENV", value: "original")
    @token.update!(scopes: ["env:write"])
    ui_pid = Queue.new
    ui = nil
    run = ServerAction::Accept.call(token: @token, endpoint: "env", target: @app, key: "env-race",
      request: {value: "api"}, request_id: "env-race-request", scope: "env:write") do |app|
      connection = ServerActionRun.connection
      connection.execute("SET LOCAL lock_timeout = '500ms'")
      ui = Thread.new do
        ServerActionRun.connection_pool.with_connection do |other|
          ui_pid << other.select_value("SELECT pg_backend_pid()")
          record = EnvVariable.find(variable.id)
          record.value = "ui"
          EnvVariable::UpdateEnvVariable.new(record).save
        rescue ServerAction::Conflict::Error
          :conflict
        end
      end
      pid = Timeout.timeout(10) { ui_pid.pop }
      refute_equal pid, connection.select_value("SELECT pg_backend_pid()")
      Timeout.timeout(10) do
        loop do
          connection.execute("SELECT pg_stat_clear_snapshot()")
          break if connection.select_value("SELECT wait_event_type = 'Lock' FROM pg_stat_activity WHERE pid = #{pid.to_i}")
          ui.value unless ui.alive?
          Thread.pass
        end
      end
      record = EnvVariable.find(variable.id)
      record.value = "api"
      command = EnvVariable::UpdateEnvVariable.new(record)
      assert command.save(enqueue: false)
      command.server_action_run
    end
    assert run.persisted?
    assert_equal :conflict, ui.value
    assert_equal "api", variable.reload.value
    assert_equal 1, ServerActionRun.where(api_token_id: @token.id).count
  ensure
    ui&.join(10) || ui&.kill
  end

  %i[api ui].each do |source|
    test "#{source} acceptance cannot deadlock a worker app status transaction touching its project" do
      accept
      results = contend(@app, before_release: -> {
        # The worker already owns the app UPDATE lock before Rails touches the
        # project. A contender must not hold that project while waiting on it.
        ServerActionRun.connection.execute("SET LOCAL lock_timeout = '500ms'")
        @app.restarting!
      }) do
        if source == :api
          accept(key: "worker-status-race")
        else
          ServerAction::Enqueue.call(action: "apps.restart", target: App.find(@app.id))
        end
      rescue ServerAction::Conflict::Error
        :conflict
      end
      assert_equal [:conflict, :conflict], results
      assert_equal "restarting", @app.reload.status
    end
  end

  %i[create update unset batch].each do |mutation|
    test "pull env reconciliation cannot invert #{mutation} preparation app and child locks" do
      variable = @app.env_variables.create!(name: "PULL_RACE", value: "original")
      exported = (mutation == :unset) ? [] : [{"name" => "REMOTE_RACE", "value" => "pull-reconciliation-secret"}]
      entered = Queue.new
      worker = nil
      @app.with_lock do
        connection = ServerActionRun.connection
        connection.execute("SET LOCAL lock_timeout = '500ms'")
        worker = Thread.new do
          ServerActionRun.connection_pool.with_connection do |other|
            run = ServerAction::Enqueue.build(action: "apps.pull_env", target: App.find(@app.id))
            transport = Object.new
            transport.define_singleton_method(:execute!) do |_command|
              raise "SSH held database locks" if other.transaction_open?
              entered << other.select_value("SELECT pg_backend_pid()")
              Struct.new(:parsed_output).new(exported)
            end
            ServerActions::PullEnv.new(run).execute!(transport)
          end
        end
        pid = Timeout.timeout(10) { entered.pop }
        refute_equal pid, connection.select_value("SELECT pg_backend_pid()")
        Timeout.timeout(10) do
          loop do
            connection.execute("SELECT pg_stat_clear_snapshot()")
            break if connection.select_value("SELECT wait_event_type = 'Lock' FROM pg_stat_activity WHERE pid = #{pid.to_i}")
            worker.value unless worker.alive?
            Thread.pass
          end
        end
        if mutation == :create
          created = @app.env_variables.new(name: "CREATED_RACE", value: "created")
          assert EnvVariable::CreateEnvVariable.new(created).save
        elsif mutation == :update
          variable.value = "changed"
          assert EnvVariable::UpdateEnvVariable.new(variable).save
        elsif mutation == :batch
          assert EnvVariable::WriteEnvVariables.new(app: @app, mode: "replace", values: {"BATCH_RACE" => "batch"}).save
        else
          EnvVariable::DestroyEnvVariable.new(variable).destroy
          assert variable.reload.discarded?
        end
      end
      worker.value
      assert_equal 1, ServerActionRun.where(target: @app, action_key: "apps.update_env").count
      assert_nil @app.env_variables.find_by(name: "REMOTE_RACE"), "export predates desired intent"
      if mutation == :create
        desired = @app.env_variables.kept.find_by!(name: "CREATED_RACE")
        assert_equal "created", desired.value
        assert desired.pending?
      elsif mutation == :update
        assert_equal "changed", variable.reload.value
        assert variable.pending?
      elsif mutation == :batch
        assert_equal "batch", @app.env_variables.kept.find_by!(name: "BATCH_RACE").value
      else
        assert variable.reload.discarded?
      end
    ensure
      worker&.join(10) || worker&.kill
    end
  end

  test "live running resource is not recovered while its real worker advisory lock is held" do
    run = accept
    run.update!(status: :running, running_at: Time.current)
    entered, release = Queue.new, Queue.new
    thread = Thread.new do
      ServerActionRun.connection_pool.with_connection do |connection|
        key = Digest::SHA256.digest(run.resource_key).unpack1("q>")
        connection.execute("SELECT pg_advisory_lock(#{key})")
        entered << connection.select_value("SELECT pg_backend_pid()")
        release.pop
        connection.execute("SELECT pg_advisory_unlock(#{key})")
      end
    end
    pid = Timeout.timeout(10) { entered.pop }
    refute_equal pid, ServerActionRun.connection.select_value("SELECT pg_backend_pid()")
    ServerAction::Recovery.recover(run)
    assert run.reload.running?
  ensure
    release << true if release
    thread&.value
  end

  private

  def accept(key: "concurrent-key", request: {}, token: @token)
    ServerAction::Accept.call(token: token.clone, endpoint: "restart", target: App.find(@app.id), key: key,
      request: request, request_id: "concurrency-request", scope: "apps:write") do
      ServerAction::Enqueue.build(action: "apps.restart", target: App.find(@app.id))
    end
  end

  def contend(record, before_release: nil)
    pids = Queue.new
    threads = []
    record.with_lock do
      threads = 2.times.map do |index|
        Thread.new do
          ServerActionRun.connection_pool.with_connection do |connection|
            pids << connection.select_value("SELECT pg_backend_pid()")
            yield index
          end
        end
      end
      workers = Timeout.timeout(10) { [pids.pop, pids.pop] }
      assert_equal 2, workers.uniq.size
      refute_includes workers, ServerActionRun.connection.select_value("SELECT pg_backend_pid()")
      Timeout.timeout(10) do
        loop do
          ServerActionRun.connection.execute("SELECT pg_stat_clear_snapshot()")
          waiting = ServerActionRun.connection.select_value("SELECT COUNT(*) FROM pg_stat_activity WHERE pid IN (#{workers.map(&:to_i).join(",")}) AND wait_event_type = 'Lock'")
          break if waiting == 2
          threads.each { |thread| thread.value unless thread.alive? }
          Thread.pass
        end
      end
      before_release&.call
    end
    threads.map(&:value)
  ensure
    threads&.each { |thread| thread.join(15) || thread.kill }
  end
end
