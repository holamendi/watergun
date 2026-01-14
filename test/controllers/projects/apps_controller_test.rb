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
    test "renders the app name" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "h1", text: @app.name
    end

    test "renders navigation tabs" do
      get project_app_path(@project, @app)

      assert_response :success

      assert_select "a[href='#{project_app_deployments_path(@project, @app)}']"
      assert_select "a[href='#{project_app_metrics_path(@project, @app)}']"
      assert_select "a[href='#{project_app_log_streams_path(@project, @app)}']"
      assert_select "a[href='#{project_app_env_variables_path(@project, @app)}']"
      assert_select "a[href='#{project_app_domains_path(@project, @app)}']"
    end

    test "renders back link to project" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "a[href='#{project_path(@project)}']", text: /#{@project.name}/
    end
  end

  describe "#edit" do
    test "renders the edit form" do
      get edit_project_app_path(@project, @app)

      assert_response :success
      assert_select "input[name='app[name]'][value='#{@app.name}']"
    end
  end

  describe "deployed app" do
    setup do
      @app.update!(status: :active, deployed_at: 1.hour.ago)
    end

    test "shows last deployed time" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "body", /deployed.*ago/i
    end

    test "shows restart action" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "form[action='#{project_app_restarts_path(@project, @app)}']"
    end
  end

  describe "app with github repo" do
    setup do
      @app = apps(:smol_roda)
      # smol_roda has a github_repo fixture
    end

    test "shows deploy action when github repo is connected" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "form[action='#{project_app_deployments_path(@project, @app)}']"
    end

    test "shows github repo link" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "a[href='#{@app.github_repo.web_url}']"
    end
  end

  describe "app with linked services" do
    setup do
      @service = services(:postgres)
      @service.update!(status: :active)
      env_var = @app.env_variables.create!(name: "DATABASE_URL", value: "postgres://localhost/test")
      ServiceLink.create!(app: @app, service: @service, env_variable: env_var)
    end

    test "shows linked services section" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "body", /Linked Services/
      assert_select "a[href='#{project_service_path(@project, @service)}']"
    end
  end
end
