require "test_helper"

class Projects::Apps::GithubReposControllerTest < ActionDispatch::IntegrationTest
  setup do
    @app = apps(:smol_roda)
    @project = @app.project
    @github_repo = @app.github_repo
    sign_in @app.account.users.first
  end

  test "updates deploy on push without changing the repository identity" do
    deploy_on_push = !@github_repo.webhook_deploy
    patch project_app_github_repo_path(@project, @app), params: {
      github_repo: {webhook_deploy: deploy_on_push, repo: "other/repo", branch: "other", account_id: accounts(:other).id}
    }, as: :turbo_stream

    assert_response :success
    assert_equal deploy_on_push, @github_repo.reload.webhook_deploy
    assert_equal "holamendi/smol-roda", @github_repo.repo
    assert_equal "main", @github_repo.branch
    assert_equal @app.account_id, @github_repo.account_id
  end

  test "renders validation errors without persisting repository settings" do
    @github_repo.update_columns(branch: "")
    webhook_deploy = @github_repo.webhook_deploy

    patch project_app_github_repo_path(@project, @app),
      params: {github_repo: {webhook_deploy: !webhook_deploy}}, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action='replace'][target='github_repo_form']"
    assert_equal webhook_deploy, @github_repo.reload.webhook_deploy
  end

  test "returns not found for a foreign account app" do
    webhook_deploy = @github_repo.webhook_deploy
    other_user = accounts(:other).users.create!(email: "other-account@example.com", password: "abc123456")
    sign_out
    sign_in other_user

    patch project_app_github_repo_path(@project, @app),
      params: {github_repo: {webhook_deploy: true}}, as: :turbo_stream

    assert_response :not_found
    assert_equal webhook_deploy, @github_repo.reload.webhook_deploy
  end

  test "returns not found for an app outside the route project" do
    patch project_app_github_repo_path(projects(:arm_project), @app),
      params: {github_repo: {webhook_deploy: true}}, as: :turbo_stream

    assert_response :not_found
  end

  test "requires a session to update repository settings" do
    sign_out

    patch project_app_github_repo_path(@project, @app),
      params: {github_repo: {webhook_deploy: true}}, as: :turbo_stream

    assert_redirected_to login_path
  end

  test "does not route unsupported repository requests" do
    path = project_app_github_repo_path(@project, @app)
    [["GET", "#{path}/new"], ["GET", "#{path}/edit"], ["GET", path], ["POST", path], ["DELETE", path]].each do |method, url|
      assert_no_difference "Github::Repo.count" do
        public_send(method.downcase, url)
      end
      assert_response :not_found
    end
  end

  test "returns not found when updating an app without a repository" do
    app = apps(:domain_test_app)

    assert_no_difference "Github::Repo.count" do
      patch project_app_github_repo_path(app.project, app),
        params: {github_repo: {webhook_deploy: true}}, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "exposes only the supported repository settings update route" do
    routes = Rails.application.routes.routes.select do |route|
      route.defaults[:controller] == "projects/apps/github_repos"
    end

    assert_equal ["update"], routes.map { |route| route.defaults[:action] }.uniq
    assert_equal ["PATCH", "PUT"], routes.map(&:verb).sort
  end
end
