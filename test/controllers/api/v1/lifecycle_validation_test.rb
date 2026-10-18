require "test_helper"

class Api::V1::LifecycleValidationTest < ActionDispatch::IntegrationTest
  # Reject through the real acceptance boundary, which must own its commit.
  self.use_transactional_tests = false

  setup do
    @app = apps(:smol_roda)
    @app.update!(status: :active, builder: :dockerfile, deployed_at: Time.current)
    @project = @app.project
    @project.server.update!(status: :active, cpu_type: :x86)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["apps:read", "apps:write", "deployments:write", "operations:read"])
    @secret = @token.token
  end

  teardown do
    ServerActionRun.where(api_token_id: @token.id).destroy_all
    ApiTokenAudit.where(api_token_id: @token.id).delete_all
    @token.destroy!
    @foreign_project&.destroy!
  end

  test "all lifecycle routes reject missing insufficient readonly expired and revoked tokens before disclosure" do
    variants = [[nil, 401], [{scopes: ["operations:read"]}, 403], [{read_only: true}, 403], [{expires_at: 1.second.ago}, 401], [{revoked_at: Time.current}, 401]]
    variants.each do |attrs, status|
      @token.update_columns(scopes: ["apps:read", "apps:write", "deployments:write"], read_only: false, expires_at: 1.day.from_now, revoked_at: nil)
      @token.update_columns(**attrs) if attrs
      headers = attrs ? auth : {}
      assert_no_difference ["App.count", "Deployment.count", "ServerActionRun.count"] do
        post create_path, params: create_body, as: :json, headers: headers
        assert_response status
        post deploy_path, params: {}, as: :json, headers: headers
        assert_response status
        post "/api/v1/apps/#{@app.id}/restarts", headers: headers
        assert_response status
        delete "/api/v1/apps/#{@app.id}", headers: headers
        assert_response status
      end
    end
  end

  test "foreign inconsistent discarded and wrong parent resources are nondisclosing" do
    foreign = @foreign_project = Project.create!(account: accounts(:other), server: servers(:other_server), name: "Foreign")
    foreign_app = foreign.apps.create!(name: "Foreign")
    assert_no_difference "ServerActionRun.count" do
      post "/api/v1/projects/#{foreign.id}/apps", params: create_body, as: :json, headers: auth
      assert_response :not_found
      [foreign_app.id, "#{@app.id}suffix", "0", "-1"].each do |id|
        post "/api/v1/apps/#{id}/deployments", params: {}, as: :json, headers: auth
        assert_response :not_found
        post "/api/v1/apps/#{id}/restarts", headers: auth
        assert_response :not_found
        delete "/api/v1/apps/#{id}", headers: auth
        assert_response :not_found
      end
      deployment = deployments(:success_deployment)
      get "/api/v1/apps/#{apps(:domain_test_app).id}/deployments/#{deployment.id}", headers: auth
      assert_response :not_found
      @app.project.update_columns(account_id: accounts(:other).id)
      delete "/api/v1/apps/#{@app.id}", headers: auth
      assert_response :not_found
      post deploy_path, params: {}, as: :json, headers: auth
      assert_response :not_found
    end
  end

  test "unknown mass assignment and command fields malformed structures and invalid types never prepare mutations" do
    invalid = [[], nil, "text", 1, create_body.merge(server_id: servers(:other_server).id), create_body.merge(account_id: accounts(:other).id),
      create_body.merge(action: "Kernel"), create_body.merge(source: "github"), create_body.merge(source: create_body[:source].merge(command: "whoami"))]
    assert_no_difference ["App.count", "Github::Repo.count", "Deployment.count", "ServerActionRun.count"] do
      invalid.each do |body|
        post create_path, params: JSON.generate(body), headers: auth.merge("CONTENT_TYPE" => "application/json")
        assert_response :bad_request
        assert_equal "invalid_request", json_response.dig("error", "code")
      end
      [{sha: []}, {sha: nil}, {sha: true}, {sha: "main;whoami"}, {sha: "a" * 39}, {sha: "a" * 40 + "\n"}].each do |body|
        post deploy_path, params: body, as: :json, headers: auth
        assert_response :unprocessable_content
      end
      [{repo: "evil/repo"}, {branch: "other"}, {builder: "dockerfile"}, {action: "apps.restart"}].each do |body|
        post deploy_path, params: body, as: :json, headers: auth
        assert_response :bad_request
      end
      post create_path, params: "{", headers: auth.merge("CONTENT_TYPE" => "application/json")
      assert_response :bad_request
      assert_equal "invalid_request", json_response.dig("error", "code")
      post deploy_path, params: {}, headers: auth
      assert_response :unsupported_media_type
      post "/api/v1/apps/#{@app.id}/restarts", params: {command: "anything"}, as: :json, headers: auth
      assert_response :bad_request
    end
  end

  test "unsupported sources build values and dangerous branch refs fail validation inline" do
    bodies = [create_body.merge(name: []), create_body.merge(name: ""), create_body.merge(name: "x\nsecret"), create_body.merge(builder: []),
      create_body.merge(builder: "custom"), create_body.merge(builder: nil), create_body.merge(source: create_body[:source].merge(type: "image")),
      create_body.merge(source: create_body[:source].merge(repo: "https://github.com/owner/repo"))]
    ["-main", "main;command\n", "main..other", "refs//main", "main.lock", "../main", "feature/@{bad}", "feature name", "x" * 256, nil, []].each do |branch|
      bodies << create_body.merge(source: create_body[:source].merge(branch: branch))
    end
    assert_no_difference ["App.count", "ServerActionRun.count"] do
      bodies.each do |body|
        post create_path, params: body, as: :json, headers: auth
        assert_response :unprocessable_content
        assert_equal "validation_failed", json_response.dig("error", "code")
      end
    end
  end

  test "missing prerequisites and invalid states return safe actionable errors and no acceptance" do
    @app.github_repo.destroy!
    post deploy_path, params: {}, as: :json, headers: auth
    assert_response :conflict
    assert_equal "prerequisite_missing", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "message"), "GitHub"
    Github::Installation.where(account: @app.account).destroy_all
    post create_path, params: create_body, as: :json, headers: auth
    assert_response :conflict
    assert_equal "prerequisite_missing", json_response.dig("error", "code")
    @project.server.update!(status: :pending)
    post "/api/v1/apps/#{@app.id}/restarts", headers: auth
    assert_response :conflict
    assert_equal "prerequisite_missing", json_response.dig("error", "code")
    @project.server.update!(status: :active)
    @app.update!(status: :pending)
    delete "/api/v1/apps/#{@app.id}", headers: auth
    assert_response :conflict
    assert_equal "operation_conflict", json_response.dig("error", "code")
  end

  test "GitHub dependency failure is sanitized unavailable and creates no phantom acceptance" do
    client = mock("github")
    Github::Installation.any_instance.stubs(:api_client).returns(client)
    client.expects(:repo).raises(Octokit::ServiceUnavailable.new(body: "dependency-private-sentinel", status: 503))
    assert_no_difference ["App.count", "ServerActionRun.count"] do
      post create_path, params: create_body, as: :json, headers: auth
      assert_response :service_unavailable
      assert_equal "unavailable", json_response.dig("error", "code")
      refute_includes response.body, "dependency-private-sentinel"
    end
  end

  test "unknown server architecture is an actionable prerequisite instead of an exception" do
    @project.server.update_columns(cpu_type: nil)
    post create_path, params: create_body, as: :json, headers: auth
    assert_response :conflict
    assert_equal "prerequisite_missing", json_response.dig("error", "code")
    post deploy_path, params: {}, as: :json, headers: auth
    assert_response :conflict
    assert_equal "prerequisite_missing", json_response.dig("error", "code")
  end

  test "uninstalled or inconsistent GitHub integration is a prerequisite not an external lookup" do
    Github::Installation.where(account_id: @app.account_id).update_all(installation_id: nil)
    assert_no_difference ["App.count", "Deployment.count", "ServerActionRun.count"] do
      post create_path, params: create_body, as: :json, headers: auth
      assert_response :conflict
      assert_equal "prerequisite_missing", json_response.dig("error", "code")
      post deploy_path, params: {}, as: :json, headers: auth
      assert_response :conflict
      assert_equal "prerequisite_missing", json_response.dig("error", "code")
    end
  end

  private

  def create_body = {name: "Test API", source: {type: "github", repo: "owner/repo", branch: "main"}, builder: "dockerfile"}
  def auth = {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => "validation"}
  def create_path = "/api/v1/projects/#{@project.id}/apps"
  def deploy_path = "/api/v1/apps/#{@app.id}/deployments"
end
