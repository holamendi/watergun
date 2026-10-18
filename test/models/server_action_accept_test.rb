require "test_helper"

class ServerActionAcceptTest < ActiveSupport::TestCase
  # Acceptance must commit domain/run/dispatch state, not an enclosing fixture.
  self.use_transactional_tests = false

  teardown do
    accepted = ServerActionRun.where(api_token_id: @token_ids)
    ids = @app_ids + accepted.where(action_key: "apps.create").pluck(:operation_app_id)
    ServerActionRun.where(resource_key: ids.compact.uniq.map { |id| "app:#{id}" }).destroy_all
    App.where(id: ids).destroy_all
    ApiTokenAudit.where(api_token_id: @token_ids).delete_all
    ApiToken.where(id: @token_ids).delete_all
  end

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "acceptance", status: :active)
    @app_ids = [@app.id]
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write", "operations:read"])
    @token_ids = [@token.id]
  end

  test "acceptance commits audit identity and dispatch intent without relying on queue availability" do
    RunServerActionJob.any_instance.stubs(:enqueue).raises(ActiveJob::EnqueueError, "private-queue-secret")
    run = accept
    assert run.persisted?
    assert run.reload.dispatch_pending_at
    assert_equal @token.id, run.api_token_id
    assert_equal @token.user_id, run.user_id
    assert_equal "acceptance-request", run.request_id
    assert_equal @app.id, run.operation_app_id
    assert_equal "queued", Api::V1::OperationResource.new(run).to_h.fetch("status")
    refute_includes Api::V1::OperationResource.new(run).serialize, "private"
  end

  test "canonical replay returns original operation before invoking domain code and different input conflicts" do
    original = accept(request: {"b" => {"d" => nil, "c" => "secret"}, "a" => 1})
    duplicate = accept(request: {a: 1, b: {c: "secret", d: nil}})
    assert_equal original.id, duplicate.id
    assert_equal original.request_id, duplicate.request_id
    error = assert_raises(ServerAction::Accept::Error) { accept(request: {"b" => {"c" => "changed"}}) }
    assert_equal "idempotency_conflict", error.code
    raw = ServerActionRun.connection.select_one("SELECT idempotency_digest, request_fingerprint FROM server_action_runs WHERE id = #{original.id}").to_json
    refute_includes raw, "secret"
    refute_includes raw, "test-key"
    original.update!(status: :success, finished_at: 60.days.ago)
    assert_equal original.id, accept(request: {a: 1, b: {c: "secret", d: nil}}).id
  end

  test "stale tokens must be reauthorized under lock even for an identical replay" do
    accept
    ApiToken.where(id: @token.id).update_all(revoked_at: Time.current)
    error = assert_raises(ServerAction::Accept::Error) { accept }
    assert_equal "unauthorized", error.code
  end

  test "missing write scope read only and removed membership reject before domain mutation" do
    [{scopes: ["operations:read"]}, {read_only: true}, {expires_at: 1.second.ago}].each do |attributes|
      @token.update_columns(**attributes)
      assert_no_difference "ServerActionRun.count" do
        assert_raises(ServerAction::Accept::Error) { accept }
      end
      @token.update_columns(scopes: ["apps:write", "operations:read"], read_only: false, expires_at: 1.day.from_now)
    end
    Membership.where(user_id: @token.user_id, account_id: @token.account_id).delete_all
    error = assert_raises(ServerAction::Accept::Error) { accept }
    assert_equal "unauthorized", error.code
  end

  test "wrong account or stale target ownership is rejected before acceptance" do
    @app.update_columns(account_id: accounts(:other).id)
    error = assert_raises(ServerAction::Accept::Error) { accept }
    assert_equal "not_found", error.code
  end

  test "a completed deleted target can replay its original operation without accepting new work" do
    original = accept
    original.update!(status: :success, finished_at: Time.current)
    @app.destroy!
    @app = App.new(id: original.operation_app_id)
    assert_equal original.id, accept.id
    assert_raises(ActiveRecord::RecordNotFound, ServerAction::Accept::Error) { accept(key: "fresh-key") }
  end

  test "a replay rechecks live target and parent ownership without disclosing transferred work" do
    original = accept
    @app.update_columns(account_id: accounts(:other).id)
    error = assert_raises(ServerAction::Accept::Error) { accept }
    assert_equal "not_found", error.code
    @app.update_columns(account_id: @token.account_id)
    @app.project.update_columns(account_id: accounts(:other).id)
    error = assert_raises(ServerAction::Accept::Error) { accept }
    assert_equal "not_found", error.code
    assert_equal original.id, ServerActionRun.where(api_token_id: @token.id).sole.id
  end

  test "the boundary composes shared creation and pins deployment without mutation controllers" do
    @app.server.update!(cpu_type: :x86)
    create = lambda do
      ServerAction::Accept.call(token: @token, endpoint: "POST /projects/:id/apps", target: @app.project,
        key: "create-domain", request: {source: {type: "github", repo: "holamendi/smol-roda", branch: "main"}},
        request_id: "domain-create", scope: "apps:write") do |project|
        command = App::CreateApp.new(project: project, repo: "holamendi/smol-roda", branch: "main")
        assert command.save(enqueue: false)
        command.server_action_run
      end
    end
    created = VCR.use_cassette("github/valid_repo_and_branch") { create.call }
    assert_equal "app.create", Api::V1::OperationResource.new(created).to_h.fetch("kind")
    assert_equal created.id, create.call.id
    created.update!(status: :success, finished_at: Time.current)
    @token.update!(scopes: ["deployments:write"])
    run = VCR.use_cassette("github/valid_commit") do
      ServerAction::Accept.call(token: @token, endpoint: "POST /apps/:id/deployments", target: created.target,
        key: "deployment-domain", request: {}, request_id: "domain-deploy", scope: "deployments:write") do |app|
        command = Deployment::CreateDeployment.new(app: app)
        command.save!(enqueue: false)
        command.server_action_run
      end
    end
    assert_equal "deployment.create", Api::V1::OperationResource.new(run).to_h.fetch("kind")
    assert_equal created.operation_app_id, run.operation_app_id
    assert_equal run.target.id, run.operation_deployment_id
    assert_equal run.target.sha, run.reload.payload["sha"]
    assert run.target.api_v1?
    assert_equal @token.user_id, run.target.user_id
  end

  test "failure storing acceptance audit rolls back domain preparation and dispatch" do
    with_public_acceptance_storage_failure(@token) do
      assert_no_difference ["App.count", "Github::Repo.count", "ServerActionRun.count"] do
        VCR.use_cassette("github/valid_repo_and_branch") do
          assert_raises(ActiveRecord::StatementInvalid) do
            ServerAction::Accept.call(token: @token, endpoint: "create", target: @app.project, key: "rollback-create",
              request: {}, request_id: "rollback-request", scope: "apps:write") do |project|
                command = App::CreateApp.new(project: project, repo: "holamendi/smol-roda", branch: "main")
                assert command.save(enqueue: false)
                command.server_action_run
              end
          end
        end
      end
    end
  end

  test "namespace separates tokens and targets while preserving null versus empty string" do
    first = accept(request: {value: nil})
    error = assert_raises(ServerAction::Accept::Error) { accept(request: {value: ""}) }
    assert_equal "idempotency_conflict", error.code
    first.update!(status: :success, finished_at: Time.current)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:write"])
    @token_ids << @token.id
    refute_equal first.id, accept(request: {value: nil}).id
    @app = @app.project.apps.create!(name: "key-namespace")
    @app_ids << @app.id
    refute_equal first.id, accept(request: {value: nil}).id
    assert_raises(ServerAction::Accept::Error) { accept(key: "invalid key") }
  end

  test "endpoint namespaces are distinct and shared env services retain encrypted acceptance" do
    first = accept
    first.update!(status: :success, finished_at: Time.current)
    @token.update!(scopes: ["env:write"])
    run = ServerAction::Accept.call(token: @token, endpoint: "PUT /apps/:id/env", target: @app,
      key: "test-key", request: {values: {PRIVATE_VALUE: "env-acceptance-sentinel"}}, request_id: "env-request", scope: "env:write") do |app|
      variable = app.env_variables.new(name: "PRIVATE_VALUE", value: "env-acceptance-sentinel")
      command = EnvVariable::CreateEnvVariable.new(variable)
      assert command.save(enqueue: false)
      command.server_action_run
    end
    refute_equal first.id, run.id
    assert_equal "app.env", Api::V1::OperationResource.new(run).to_h.fetch("kind")
    assert_equal "env-acceptance-sentinel", run.reload.payload.fetch("set").fetch("PRIVATE_VALUE")
    raw = ServerActionRun.connection.select_one("SELECT * FROM server_action_runs WHERE id = #{run.id}").to_json
    refute_includes raw, "env-acceptance-sentinel"
    refute_includes raw, @token.token
    refute_includes Api::V1::OperationResource.new(run).serialize, "env-acceptance-sentinel"
  end

  test "acceptance owns a new run and rejects persisted or mismatched work" do
    existing = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    assert_raises(ArgumentError) do
      ServerAction::Accept.call(token: @token, endpoint: "restart", target: @app, key: "existing",
        request: {}, request_id: "existing-request", scope: "apps:write") { existing }
    end
    assert_nil existing.reload.api_token_id
    existing.update!(status: :success, finished_at: Time.current)
    other = @app.project.apps.create!(name: "unrelated-acceptance")
    @app_ids << other.id
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) do
        ServerAction::Accept.call(token: @token, endpoint: "restart", target: @app, key: "extra",
          request: {}, request_id: "extra-request", scope: "apps:write") do
          ServerAction::Enqueue.build(action: "apps.restart", target: other)
        end
      end
    end
  end

  private

  def accept(key: "test-key", request: {})
    ServerAction::Accept.call(token: @token, endpoint: "POST /apps/:id/restarts", target: @app,
      key: key, request: request, request_id: "acceptance-request", scope: "apps:write") do
      ServerAction::Enqueue.build(action: "apps.restart", target: @app)
    end
  end
end
