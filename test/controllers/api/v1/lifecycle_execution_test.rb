require "test_helper"

class Api::V1::LifecycleExecutionTest < ActionDispatch::IntegrationTest
  include SshTestHelper

  # Actual HTTP acceptance and worker finalization must survive separate commits.
  self.use_transactional_tests = false

  setup do
    @server = servers(:amd)
    @server.update!(status: :active, cpu_type: :x86)
    @project = Project.create!(account: @server.account, server: @server, name: "Lifecycle HTTP")
    @token = ApiToken.create!(account: @project.account, user: users(:bobby), scopes: ["apps:read", "apps:write", "deployments:write", "operations:read"])
    @secret = @token.token
    @client = mock("github")
    Github::Installation.any_instance.stubs(:api_client).returns(@client)
    @client.stubs(:repo).returns(stub(private?: false))
    @client.stubs(:branch).returns(stub(commit: stub(sha: "c" * 40, author: nil,
      commit: stub(author: nil, message: "HTTP lifecycle"), html_url: "https://github.com/owner/repo/commit/#{"c" * 40}")))
  end

  teardown do
    ids = @project.apps.pluck(:id) + ServerActionRun.where(api_token_id: @token.id).pluck(:operation_app_id)
    ServerActionRun.where(resource_key: ids.compact.uniq.map { |id| "app:#{id}" }).destroy_all
    @project.destroy!
    @event&.destroy!
    ApiTokenAudit.where(api_token_id: @token.id).delete_all
    @token.destroy!
    sign_out if cookies[:session_token]
  end

  test "complete HTTP supported lifecycle prepares creates deploys reads restarts and deletes through actual jobs" do
    post "/api/v1/projects/#{@project.id}/apps", params: create_body, as: :json, headers: auth("create")
    assert_response :accepted
    create_run = accepted_run
    app = App.find(create_run.operation_app_id)
    transport [{cmd: "dokku apps:create #{app.dokku_id}"},
      {cmd: "dokku domains:report #{app.dokku_id}", stdout: file_fixture("dokku/domains/report_command_output.txt").read}]
    perform(create_run)
    assert app.reload.active?
    assert_operation create_run, "succeeded"
    post "/api/v1/apps/#{app.id}/deployments", params: {}, as: :json, headers: auth("deploy")
    assert_response :accepted
    deploy_run = accepted_run
    assert deploy_run.target.pending?
    transport [{cmd: "dokku builder:set #{app.dokku_id} selected dockerfile"},
      {cmd: "dokku git:auth github.com u #{@project.account.github_installation.access_token.token}"},
      {cmd: "dokku git:sync #{app.dokku_id} https://github.com/owner/repo.git #{"c" * 40}"},
      {cmd: "dokku ps:rebuild #{app.dokku_id}"}]
    # Domain lookup is a remote DNS prerequisite, not a mocked domain/queue boundary.
    Resolv.stubs(:getaddress).returns("192.0.2.1")
    perform(deploy_run)
    assert deploy_run.target.reload.success?
    assert app.reload.deployed?
    assert_operation deploy_run, "succeeded"
    post "/api/v1/apps/#{app.id}/deployments", params: {}, as: :json, headers: auth("deploy")
    assert_response :accepted
    assert_equal deploy_run.id, json_response.dig("operation", "id")
    get "/api/v1/apps/#{app.id}/deployments", headers: auth("read")
    assert_response :ok
    assert_equal [deploy_run.target_id], json_response.fetch("deployments").map { |row| row.fetch("id") }
    get "/api/v1/apps/#{app.id}", headers: auth("read")
    assert_response :ok
    assert_equal "active", json_response.dig("app", "status")
    assert_equal deploy_run.target_id, json_response.dig("app", "deployment", "id")
    post "/api/v1/apps/#{app.id}/restarts", headers: auth("restart")
    assert_response :accepted
    restart_run = accepted_run
    transport [{cmd: "dokku ps:restart #{app.dokku_id}"}]
    perform(restart_run)
    assert_operation restart_run, "succeeded"
    delete "/api/v1/apps/#{app.id}", headers: auth("delete")
    assert_response :accepted
    delete_run = accepted_run
    transport [{cmd: "dokku apps:destroy --force #{app.dokku_id}"}]
    perform(delete_run)
    assert_operation delete_run, "succeeded"
    assert_nil App.find_by(id: app.id)
    assert_nil Deployment.find_by(id: deploy_run.target_id)
    assert_operation deploy_run, "succeeded"
    delete "/api/v1/apps/#{app.id}", headers: auth("delete")
    assert_response :accepted
    assert_equal delete_run.id, json_response.dig("operation", "id")
  end

  test "remote create deploy and delete failures remain inspectable with safe failure context" do
    post "/api/v1/projects/#{@project.id}/apps", params: create_body, as: :json, headers: auth("failed-create")
    assert_response :accepted
    create_run = accepted_run
    app = create_run.target
    transport [{cmd: "dokku apps:create #{app.dokku_id}", exit_code: 1, stderr: "remote-private-sentinel"}]
    perform(create_run)
    assert app.reload.error?
    assert_operation create_run, "failed"
    get "/api/v1/apps/#{app.id}", headers: auth("read")
    assert_response :ok
    assert_equal "error", json_response.dig("app", "status")
    post "/api/v1/apps/#{app.id}/deployments", params: {}, as: :json, headers: auth("failed-deploy")
    assert_response :accepted
    deploy_run = accepted_run
    transport [{cmd: "dokku builder:set #{app.dokku_id} selected dockerfile", exit_code: 1, stderr: "remote-private-sentinel"}]
    perform(deploy_run)
    assert app.reload.error?
    get "/api/v1/apps/#{app.id}/deployments/#{deploy_run.target_id}", headers: auth("read")
    assert_response :ok
    assert_equal "error", json_response.dig("deployment", "status")
    assert_operation deploy_run, "failed"
    delete "/api/v1/apps/#{app.id}", headers: auth("failed-delete")
    assert_response :accepted
    delete_run = accepted_run
    transport [{cmd: "dokku apps:destroy --force #{app.dokku_id}", exit_code: 1, stderr: "remote-private-sentinel"}]
    perform(delete_run)
    assert app.reload.error?
    assert_operation delete_run, "failed"
    get "/api/v1/apps/#{app.id}", headers: auth("read")
    assert_response :ok
    delete "/api/v1/apps/#{app.id}", headers: auth("failed-delete")
    assert_response :accepted
    assert_equal delete_run.id, json_response.dig("operation", "id")
  end

  %w[ui webhook].each do |entry_point|
    test "API selected builder survives the first deployment through #{entry_point}" do
      body = create_body.merge(builder: "nixpacks")
      post "/api/v1/projects/#{@project.id}/apps", params: body, as: :json, headers: auth("mixed-#{entry_point}")
      assert_response :accepted
      create_run = accepted_run
      app = create_run.target
      transport [{cmd: "dokku apps:create #{app.dokku_id}"},
        {cmd: "dokku domains:report #{app.dokku_id}", stdout: file_fixture("dokku/domains/report_command_output.txt").read}]
      perform(create_run)

      if entry_point == "ui"
        sign_in users(:bobby)
        post project_app_deployments_path(@project, app)
        assert_response :ok
      else
        app.github_repo.update!(webhook_deploy: true)
        @client.stubs(:commit).with("owner/repo", "c" * 40).returns(stub(sha: "c" * 40, author: nil,
          commit: stub(author: nil, message: "HTTP lifecycle"), html_url: "https://github.com/owner/repo/commit/#{"c" * 40}"))
        event = @event = Github::Event.create!(account: @project.account, installation: @project.account.github_installation,
          headers: {"HTTP_X_GITHUB_EVENT" => "push"}, payload: {ref: "refs/heads/main", after: "c" * 40, repository: {full_name: "owner/repo"}})
        Github::ProcessEventJob.perform_now(event)
        assert event.reload.processed?
      end

      run = app.deployments.order(:id).last.server_action_run
      assert_equal "nixpacks", run.payload["builder"]
      app.update!(builder: :dockerfile)
      transport [{cmd: "dokku builder:set #{app.dokku_id} selected nixpacks"},
        {cmd: "dokku git:auth github.com u #{@project.account.github_installation.access_token.token}"},
        {cmd: "dokku git:sync #{app.dokku_id} https://github.com/owner/repo.git #{"c" * 40}"},
        {cmd: "dokku ps:rebuild #{app.dokku_id}"}]
      Resolv.stubs(:getaddress).returns("192.0.2.1")
      perform(run)
      assert run.reload.success?
      assert run.target.reload.success?
    end
  end

  private

  def transport(commands)
    mock_ssh_session(host: @server.public_ip, user: SshKey::USER, port: @server.ssh_port,
      private_key: @server.ssh_key.private_key, commands: commands, ordered: true)
  end

  def perform(run) = RunServerActionJob.perform_now(run.id, run.resource_key)
  def accepted_run = ServerActionRun.find(json_response.dig("operation", "id"))
  def auth(key) = {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key}
  def create_body = {name: "Lifecycle HTTP", source: {type: "github", repo: "owner/repo", branch: "main"}, builder: "dockerfile"}

  def assert_operation(run, status)
    get "/api/v1/operations/#{run.id}", headers: auth("poll")
    assert_response :ok
    assert_equal status, json_response.dig("operation", "status")
    assert_equal "remote_failed", json_response.dig("operation", "error", "code") if status == "failed"
    refute_match(/remote-private-sentinel|payload|token|private_key|failure_message/, response.body)
  end
end
