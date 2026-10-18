require "test_helper"
require "timeout"

class Api::V1::LifecycleConcurrencyTest < ActiveSupport::TestCase
  # Independent HTTP sessions must contend over committed acceptance state.
  self.use_transactional_tests = false

  setup do
    @app = apps(:smol_roda)
    @app.update!(status: :active, builder: :dockerfile, deployed_at: Time.current)
    @app.server.update!(status: :active, cpu_type: :x86)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write", "deployments:write"])
    @secret = @token.token
    @client = mock("github")
    Github::Installation.any_instance.stubs(:api_client).returns(@client)
    @client.stubs(:repo).returns(stub(private?: false))
    @client.stubs(:branch).returns(stub(commit: stub(sha: "d" * 40, author: nil,
      commit: stub(author: nil, message: "concurrent"), html_url: "https://github.com/owner/repo/commit/#{"d" * 40}")))
  end

  teardown do
    runs = ServerActionRun.where(api_token_id: @token.id)
    created_apps = runs.where(action_key: "apps.create").pluck(:operation_app_id)
    created_deployments = runs.where(action_key: "apps.deploy").pluck(:operation_deployment_id)
    runs.destroy_all
    Deployment.where(id: created_deployments).destroy_all
    App.where(id: created_apps).destroy_all
    ApiTokenAudit.where(api_token_id: @token.id).delete_all
    @token.destroy!
  end

  test "concurrent HTTP identical create retries persist exactly one app repo and durable operation" do
    body = {name: "Concurrent HTTP", source: {type: "github", repo: "owner/repo", branch: "main"}, builder: "dockerfile"}
    assert_difference ["App.count", "Github::Repo.count", "ServerActionRun.count"], 1 do
      results = compete([:post, "/api/v1/projects/#{@app.project_id}/apps", body, "create"], [:post, "/api/v1/projects/#{@app.project_id}/apps", body, "create"])
      assert_equal [202, 202], results.map(&:status)
      assert_equal 1, results.map { |result| JSON.parse(result.body).dig("operation", "id") }.uniq.size
    end
  end

  test "concurrent HTTP identical deployments persist exactly one pinned deployment and operation" do
    path = "/api/v1/apps/#{@app.id}/deployments"
    assert_difference ["Deployment.count", "ServerActionRun.count"], 1 do
      results = compete([:post, path, {}, "deploy"], [:post, path, {}, "deploy"])
      assert_equal [202, 202], results.map(&:status)
      assert_equal 1, results.map { |result| JSON.parse(result.body).dig("operation", "deployment_id") }.uniq.size
    end
  end

  test "concurrent HTTP distinct mutations on same app have a single winner" do
    assert_difference "ServerActionRun.count", 1 do
      results = compete([:post, "/api/v1/apps/#{@app.id}/restarts", nil, "restart"], [:delete, "/api/v1/apps/#{@app.id}", nil, "delete"])
      assert_equal [202, 409], results.map(&:status).sort
      assert_equal "operation_conflict", JSON.parse(results.find { |result| result.status == 409 }.body).dig("error", "code")
    end
  end

  test "concurrent HTTP same key with different logical input conflicts without two creations" do
    body = {name: "First", source: {type: "github", repo: "owner/repo", branch: "main"}, builder: "dockerfile"}
    assert_difference ["App.count", "ServerActionRun.count"], 1 do
      path = "/api/v1/projects/#{@app.project_id}/apps"
      results = compete([:post, path, body, "same"], [:post, path, body.merge(name: "Second"), "same"])
      assert_equal [202, 409], results.map(&:status).sort
      assert_equal "idempotency_conflict", JSON.parse(results.find { |result| result.status == 409 }.body).dig("error", "code")
    end
  end

  test "two concurrent slow preparations resolve different HEADs but accept only the winning snapshot" do
    entered = Queue.new
    release = Queue.new
    resolved = Queue.new
    client = Object.new
    client.define_singleton_method(:repo) { |_repo| true }
    client.define_singleton_method(:branch) do |_repo, _branch|
      connection = ActiveRecord::Base.connection
      raise "GitHub read inside transaction" if connection.transaction_open?
      entered << connection.select_value("SELECT pg_backend_pid()")
      sha = release.pop
      resolved << sha
      Struct.new(:commit).new(Struct.new(:sha, :author, :commit, :html_url).new(sha, nil,
        Struct.new(:author, :message).new(nil, "prepared #{sha}"), "https://github.com/owner/repo/commit/#{sha}"))
    end
    Github::Installation.any_instance.stubs(:api_client).returns(client)
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post "/api/v1/apps/#{@app.id}/deployments", params: {}, as: :json,
            headers: {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => "slow-race"}
          session.response
        end
      end
    end
    sessions = Timeout.timeout(15) { 2.times.map { entered.pop } }
    assert_equal 2, sessions.uniq.size
    refute_includes sessions, ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
    assert_equal 0, ServerActionRun.where(api_token_id: @token.id).count
    before = Deployment.count
    release << "e" * 40
    release << "f" * 40
    responses = Timeout.timeout(15) { threads.map(&:value) }
    assert_equal ["e" * 40, "f" * 40], 2.times.map { resolved.pop }.sort
    assert_equal [202, 202], responses.map(&:status)
    assert_equal 1, responses.map { |response| JSON.parse(response.body).dig("operation", "id") }.uniq.size
    assert_equal before + 1, Deployment.uncached { Deployment.count }
    run = ServerActionRun.where(api_token_id: @token.id).sole
    assert_includes ["e" * 40, "f" * 40], run.target.sha
    assert_equal run.target.sha, run.payload.fetch("sha")
    assert_equal "dockerfile", run.payload.fetch("builder")
  ensure
    2.times { release << "e" * 40 } if release
    threads&.each { |thread| thread.join(15) || thread.kill.join(10) }
  end

  private

  def compete(*requests)
    pids = Queue.new
    threads = []
    @token.with_lock do
      threads = requests.map do |method, path, body, key|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            pids << connection.select_value("SELECT pg_backend_pid()")
            session = ActionDispatch::Integration::Session.new(Rails.application)
            args = {headers: {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key}}
            if body
              args[:params] = body
              args[:as] = :json
            end
            session.public_send(method, path, **args)
            session.response
          end
        end
      end
      worker_pids = Timeout.timeout(10) { requests.map { pids.pop } }
      assert_equal requests.length, worker_pids.uniq.length
      refute_includes worker_pids, ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
      Timeout.timeout(10) do
        loop do
          ActiveRecord::Base.connection.execute("SELECT pg_stat_clear_snapshot()")
          waiting = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM pg_stat_activity WHERE pid IN (#{worker_pids.map(&:to_i).join(",")}) AND wait_event_type = 'Lock'")
          break if waiting == requests.length
          threads.each { |thread| thread.value unless thread.alive? }
          Thread.pass
        end
      end
    end
    Timeout.timeout(15) { threads.map(&:value) }
  ensure
    threads.each { |thread| thread.join(15) || thread.kill.join(10) }
  end
end
