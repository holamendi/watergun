require "test_helper"

class Projects::Apps::DeploymentsControllerTest < ActionDispatch::IntegrationTest
  describe "#create" do
    setup do
      @github_repo = github_repos(:smol_roda)
      @app = @github_repo.app
      @account = @app.account
      @project = @app.project
      @server = @app.server
      @user = @account.users.first
    end

    test "creates a deployment with the last commit when no sha is provided" do
      sign_in @user

      VCR.use_cassette("github/valid_commit") do
        assert_difference -> { @app.deployments.count }, 1 do
          post project_app_deployments_url(project_id: @project.id, app_id: @app.id)
        end
      end

      deployment = @app.deployments.last
      assert_equal "pending", deployment.status
      assert_equal @github_repo.repo, deployment.repo
      assert deployment.sha.present?

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

      assert_turbo_stream action: "append", target: "toasts", status: :ok do
        assert_select "p", text: "Smol Roda: deployment scheduled"
      end
    end

    test "creates a deployment with the provided sha" do
      sha = "714b020"
      sign_in @user

      VCR.use_cassette("github/valid_commit_with_sha_714b020") do
        assert_difference -> { @app.deployments.count }, 1 do
          post project_app_deployments_url(project_id: @project.id, app_id: @app.id, params: {sha:})
        end
      end

      deployment = @app.deployments.last
      assert_equal "pending", deployment.status
      assert_equal @github_repo.repo, deployment.repo
      assert_equal sha, deployment.short_sha

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

      assert_turbo_stream action: "append", target: "toasts", status: :ok do
        assert_select "p", text: "Smol Roda: deployment scheduled"
      end
    end

    test "fails when the sha is not found" do
      sha = "invalid"
      sign_in @user

      VCR.use_cassette("github/invalid_commit") do
        assert_no_difference -> { @app.deployments.count } do
          post project_app_deployments_url(project_id: @project.id, app_id: @app.id, params: {sha:})
        end
      end

      assert_turbo_stream action: "append", target: "toasts", status: :unprocessable_entity do
        assert_select "p", text: "Invalid deployment parameters"
      end
    end
  end
end
