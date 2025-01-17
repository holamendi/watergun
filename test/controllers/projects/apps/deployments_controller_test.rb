require "test_helper"

class Projects::Apps::DeploymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @github_repo = github_repos(:smol_roda)
    @app = @github_repo.app
    @account = @app.account
    @project = @app.project
    @server = @app.server
    @user = @account.users.first
  end
  test "#create creates a deployment with the last commit when no sha is provided" do
    sign_in @user

    VCR.use_cassette("github/valid_commit") do
      assert_difference -> { @app.deployments.count }, 1 do
        post project_app_deployments_url(project_id: @project.id, app_id: @app.id)
      end
    end

    deployment = @app.deployments.last

    assert_server_action_scheduled(
      ServerActions::DeployApp,
      server: @server,
      actionable: deployment,
      payload: {
        dokku_app_id: @app.dokku_id,
        repo: deployment.repo,
        sha: deployment.sha
      }
    )

    assert_response :ok
    assert_turbo_stream action: "append", target: "toasts" do
      assert_select "p", text: "Smol Roda: deployment scheduled"
    end
  end
end
