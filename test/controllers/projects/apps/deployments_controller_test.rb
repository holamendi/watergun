require "test_helper"

class Projects::Apps::DeploymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @github_repo = github_repos(:smol_roda)
    @app = @github_repo.app
    @account = @app.account
    @project = @app.project
    @server = @app.server
    @user = @account.users.first

    sign_in @user
  end

  describe "#index" do
    test "renders deployments with links to show page" do
      deployment = deployments(:success_deployment)

      get project_app_deployments_path(@project, @app)

      assert_response :success
      assert_select "a[href='#{project_app_deployment_path(@project, @app, deployment)}']"
      assert_select "form[action='#{project_app_deployments_path(@project, @app)}'] button", text: "Deploy"
    end
  end

  describe "#show" do
    test "renders completed deployment with info card, logs section, and navigation" do
      deployment = deployments(:success_deployment)

      get project_app_deployment_path(@project, @app, deployment)

      assert_response :success
      assert_select "##{dom_id(deployment, :info)}"
      assert_select "##{dom_id(deployment, :logs)}"
      assert_select "a[href='#{project_app_deployments_path(@project, @app)}']"
      assert_select "a[href='#{project_app_settings_path(@project, @app)}']"
      assert_select "body", /#{deployment.short_sha}/
      assert_select "body", /Completed in/
    end

    test "renders in-progress deployment with turbo subscription" do
      deployment = deployments(:deploying_deployment)

      get project_app_deployment_path(@project, @app, deployment)

      assert_response :success
      assert_select "body", /Deploying/
      assert_select "turbo-cable-stream-source[signed-stream-name]"
    end
  end

  describe "#create" do
    test "creates a deployment with the last commit when no sha is provided" do
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

      VCR.use_cassette("github/invalid_commit") do
        assert_no_difference -> { @app.deployments.count } do
          post project_app_deployments_url(project_id: @project.id, app_id: @app.id, params: {sha:})
        end
      end

      assert_turbo_stream action: "append", target: "toasts", status: :unprocessable_content do
        assert_select "p", text: "Invalid deployment parameters"
      end
    end
  end
end
