require "test_helper"
require "json_schemer"

class Api::V1::LifecycleSourcesTest < ActionDispatch::IntegrationTest
  # Real acceptance owns its commit; an enclosing fixture transaction is invalid.
  self.use_transactional_tests = false

  setup do
    @project = projects(:default)
    @project.server.update!(status: :active, cpu_type: :x86)
    @token = ApiToken.create!(account: @project.account, user: users(:bobby), scopes: ["apps:read", "apps:write", "deployments:write", "operations:read"])
    @secret = @token.token
    @client = mock("GitHub API")
    @client.stubs(:repo).returns(stub(private?: false))
    Github::Installation.any_instance.stubs(:api_client).returns(@client)
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

  test "create pins supported GitHub source and builder and replay skips external prerequisites" do
    @client.expects(:repo).with("owner/repo").once.returns(stub(private?: true))
    @client.expects(:branch).with("owner/repo", "feature/full-branch").once.returns(stub(name: "feature/full-branch"))
    Server.any_instance.expects(:ssh_session).never
    assert_difference ["App.count", "Github::Repo.count", "ServerActionRun.count"], 1 do
      post create_path, params: create_body, as: :json, headers: auth("create")
      assert_response :accepted
    end
    operation = json_response.fetch("operation")
    app = App.find(operation.fetch("app_id"))
    assert_equal @project.id, app.project_id
    assert_equal @project.server_id, app.server_id
    assert_equal "dockerfile", app.builder
    assert_equal "feature/full-branch", app.github_repo.branch
    assert app.github_repo.private?
    assert_equal "pending", app.status
    assert_equal "app.create", operation.fetch("kind")
    refute_match(/token|payload|private_key/, response.body)
    assert_no_difference ["App.count", "Github::Repo.count", "ServerActionRun.count"] do
      post create_path, params: create_body, as: :json, headers: auth("create")
      assert_response :accepted
      assert_equal operation, json_response.fetch("operation")
      post create_path, params: create_body.merge(name: "Changed"), as: :json, headers: auth("create")
      assert_response :conflict
      assert_equal "idempotency_conflict", json_response.dig("error", "code")
    end
  end

  test "deployment resolves configured branch once outside row locks and pins source SHA and builder" do
    app = apps(:smol_roda)
    app.update!(status: :active, builder: :nixpacks)
    sha = "a" * 40
    @client.expects(:branch).with do |repo, branch|
      refute ActiveRecord::Base.connection.transaction_open?, "GitHub lookup must not hold database locks"
      repo == app.github_repo.repo && branch == app.github_repo.branch
    end.once.returns(stub(commit: commit(sha)))
    Server.any_instance.expects(:ssh_session).never
    path = "/api/v1/apps/#{app.id}/deployments"
    post path, params: {}, as: :json, headers: auth("deploy")
    assert_response :accepted
    operation = json_response.fetch("operation")
    deployment = Deployment.find(operation.fetch("deployment_id"))
    assert_equal "api_v1", deployment.source
    assert_equal @token.user_id, deployment.user_id
    assert_equal app.github_repo.repo, deployment.repo
    assert_equal sha, deployment.sha
    run = ServerActionRun.find(operation.fetch("id"))
    assert_equal "nixpacks", run.payload.fetch("builder")
    assert_equal sha, run.payload.fetch("sha")
    post path, params: {}, as: :json, headers: auth("deploy")
    assert_response :accepted
    assert_equal operation, json_response.fetch("operation")
    post path, params: {sha: "b" * 40}, as: :json, headers: auth("deploy")
    assert_response :conflict
    assert_equal "idempotency_conflict", json_response.dig("error", "code")
    get "#{path}/#{deployment.id}", headers: auth("read")
    assert_response :ok
    assert_equal sha, json_response.dig("deployment", "sha")
  end

  test "explicit SHA is resolved only within configured repository and default builder replay is canonical" do
    body = create_body.except(:builder)
    @client.expects(:repo).once.returns(stub(private?: false))
    @client.expects(:branch).once.returns(stub(name: "feature/full-branch"))
    post create_path, params: body, as: :json, headers: auth("default-builder")
    assert_response :accepted
    operation = json_response.fetch("operation")
    post create_path, params: body.merge(builder: "herokuish"), as: :json, headers: auth("default-builder")
    assert_response :accepted
    assert_equal operation, json_response.fetch("operation")
    app = apps(:smol_roda)
    app.update!(status: :active, builder: :herokuish)
    sha = "b" * 40
    @client.expects(:commit).with(app.github_repo.repo, sha).returns(commit(sha))
    post "/api/v1/apps/#{app.id}/deployments", params: {sha: sha}, as: :json, headers: auth("sha")
    assert_response :accepted
    assert_equal sha, ServerActionRun.find(json_response.dig("operation", "id")).payload.fetch("sha")
  end

  test "source changes during remote preparation reject without a stale deployment" do
    app = apps(:smol_roda)
    app.update!(status: :active, builder: :dockerfile)
    @client.expects(:branch).with do |repo, branch|
      app.update!(builder: :nixpacks)
      repo == app.github_repo.repo && branch == app.github_repo.branch
    end.once.returns(stub(commit: commit("a" * 40)))
    assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
      post "/api/v1/apps/#{app.id}/deployments", params: {}, as: :json, headers: auth("source-changed")
      assert_response :conflict
      assert_equal "operation_conflict", json_response.dig("error", "code")
    end
  end

  test "revocation during slow preparation prevents acceptance after external reads" do
    @client.expects(:repo).with do |repo|
      @token.update_columns(revoked_at: Time.current)
      repo == "owner/repo"
    end.once.returns(stub(private?: false))
    @client.expects(:branch).returns(stub(name: "feature/full-branch"))
    assert_no_difference ["App.count", "ServerActionRun.count"] do
      post create_path, params: create_body, as: :json, headers: auth("revoked-during-prepare")
      assert_response :unauthorized
      assert_equal "unauthorized", json_response.dig("error", "code")
    end
  end

  test "source resolution must return a full immutable commit rather than a command or moving ref" do
    app = apps(:smol_roda)
    app.update!(status: :active, builder: :dockerfile)
    @client.expects(:branch).returns(stub(commit: commit("main;private-sentinel")))
    assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
      post "/api/v1/apps/#{app.id}/deployments", params: {}, as: :json, headers: auth("invalid-resolved-ref")
      assert_response :unprocessable_content
      assert_equal "validation_failed", json_response.dig("error", "code")
      refute_includes response.body, "private-sentinel"
    end
  end

  test "create audit failure rolls back app repository and run through the real HTTP boundary" do
    @client.expects(:repo).returns(stub(private?: false))
    @client.expects(:branch).returns(stub(name: "feature/full-branch"))
    with_public_acceptance_storage_failure(@token) do
      assert_no_difference ["App.count", "Github::Repo.count", "ServerActionRun.count"] do
        post create_path, params: create_body, as: :json, headers: auth("create-audit-rollback")
        assert_response :service_unavailable
        assert_equal "unavailable", json_response.dig("error", "code")
        refute_includes response.body, "test acceptance storage unavailable"
      end
    end
  end

  test "repository not found and missing branch reject without a local app or remote command" do
    @client.expects(:repo).with("owner/repo").raises(Octokit::NotFound)
    assert_no_difference ["App.count", "ServerActionRun.count"] do
      post create_path, params: create_body, as: :json, headers: auth("missing-repo")
      assert_response :conflict
      assert_equal "prerequisite_missing", json_response.dig("error", "code")
    end
    @client.expects(:repo).with("owner/repo").returns(stub(private?: false))
    @client.expects(:branch).with("owner/repo", "feature/full-branch").raises(Octokit::NotFound)
    assert_no_difference ["App.count", "ServerActionRun.count"] do
      post create_path, params: create_body, as: :json, headers: auth("missing-branch")
      assert_response :unprocessable_content
    end
  end

  test "deployment repository access failure is an actionable prerequisite not an invalid commit" do
    app = apps(:smol_roda)
    app.update!(status: :active, builder: :dockerfile)
    @client.expects(:repo).with(app.github_repo.repo).raises(Octokit::NotFound)
    @client.expects(:branch).never
    assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
      post "/api/v1/apps/#{app.id}/deployments", params: {}, as: :json, headers: auth("lost-repo-access")
      assert_response :conflict
      assert_equal "prerequisite_missing", json_response.dig("error", "code")
    end
  end

  private

  def commit(sha)
    stub(sha: sha, author: nil, commit: stub(author: nil, message: "snapshot"), html_url: "https://github.com/owner/repo/commit/#{sha}")
  end

  def create_body
    {name: "API App", source: {type: "github", repo: "owner/repo", branch: "feature/full-branch"}, builder: "dockerfile"}
  end

  def create_path = "/api/v1/projects/#{@project.id}/apps"
  def auth(key) = {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key}
end
