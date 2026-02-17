require "test_helper"

class Projects::AppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
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
    test "renders general settings page" do
      get project_app_settings_path(@project, @app)

      assert_response :success
      assert_select "body", /General/
      assert_select "a[href='#{project_app_env_variables_path(@project, @app)}']"
      assert_select "a[href='#{project_app_domains_path(@project, @app)}']"
    end
  end
end
