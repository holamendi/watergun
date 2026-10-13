require "test_helper"

class Projects::AppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
  end

  describe "#new" do
    test "guides accounts without a GitHub installation to account settings" do
      Github::Installation.where(account: @account).destroy_all

      get new_project_app_path(@project)

      assert_response :success
      assert_select "a[href='#{account_path}']", text: "Connect GitHub"

      get account_path
      assert_response :success
      assert_select "a[href='#{@account.github_app.new_installation_url}']", text: "Connect GitHub"
    end

    test "selects the repository during app creation" do
      get new_project_app_path(@project)

      assert_response :success
      assert_select "form[action='#{project_apps_path(@project)}']" do
        assert_select "input[name='create_app[repo]']:not([disabled])"
        assert_select "input[name='create_app[branch]']:not([disabled])"
      end
    end
  end

  describe "#index" do
    test "renders app list with project-scoped links" do
      get project_apps_path(@project)

      assert_response :success
      assert_select "a[href='#{new_project_app_path(@project)}']", text: "Create New App"
      assert_select "a[href='#{project_app_deployments_path(@project, @app)}']"
    end
  end

  describe "#show" do
    test "redirects to deployments" do
      get project_app_path(@project, @app)

      assert_redirected_to project_app_deployments_path(@project, @app)
    end
  end

  describe "#edit" do
    test "redirects to settings" do
      get edit_project_app_path(@project, @app)

      assert_redirected_to project_app_settings_path(@project, @app)
    end
  end

  describe "app tabs" do
    test "render only deployments metrics logs and settings" do
      get project_app_deployments_path(@project, @app)

      assert_response :success
      assert_select "a[href='#{project_app_deployments_path(@project, @app)}']"
      assert_select "a[href='#{project_app_metrics_path(@project, @app)}']"
      assert_select "a[href='#{project_app_log_streams_path(@project, @app)}']"
      assert_select "a[href='#{project_app_settings_path(@project, @app)}']"

      assert_select "a[href='#{project_app_path(@project, @app)}']", count: 0
      assert_select "a[href='#{project_app_env_variables_path(@project, @app)}']", count: 0
      assert_select "a[href='#{project_app_domains_path(@project, @app)}']", count: 0
    end
  end

  describe "settings pages" do
    test "does not offer a repository form for an app without a repository" do
      app = apps(:domain_test_app)

      get project_app_settings_path(app.project, app)

      assert_response :success
      assert_select "#repository form", count: 0
      assert_select "#repository", /Repositories are selected when creating an app\./
      assert_select "#repository a[href='#{new_project_app_path(app.project)}']", text: "Create App"
    end

    test "renders general settings page" do
      get project_app_settings_path(@project, @app)

      assert_response :success
      assert_select "body", /General/
      assert_select "a[href='#{project_app_env_variables_path(@project, @app)}']"
      assert_select "a[href='#{project_app_domains_path(@project, @app)}']"
      assert_select "[data-ui-component='danger-zone']"
      assert_select "a[data-ui-component='button'][data-turbo-method='delete'][href='#{project_app_path(@project, @app)}']"
    end
  end
end
