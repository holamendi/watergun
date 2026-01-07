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
    test "renders the sidebar with app context" do
      get project_app_path(@project, @app)

      assert_response :success

      # App header with name and status badge
      assert_select "[data-sidebar-target='panel']" do
        assert_select ".font-semibold", text: @app.name
      end
    end

    test "renders the sidebar with server name" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "body", /on #{@app.server.name}/
    end

    test "renders navigation links without counter badges" do
      get project_app_path(@project, @app)

      assert_response :success

      # Navigation links should exist
      assert_select "a[href='#{project_app_deployments_path(@project, @app)}']"
      assert_select "a[href='#{project_app_metrics_path(@project, @app)}']"
      assert_select "a[href='#{project_app_log_streams_path(@project, @app)}']"
      assert_select "a[href='#{project_app_env_variables_path(@project, @app)}']"
      assert_select "a[href='#{project_app_domains_path(@project, @app)}']"
      assert_select "a[href='#{edit_project_app_path(@project, @app)}']"
    end

    test "renders back link to project" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "a[href='#{project_path(@project)}']", text: /#{@project.name}/
    end
  end

  describe "#edit" do
    test "renders the sidebar with app context" do
      get edit_project_app_path(@project, @app)

      assert_response :success
      assert_select ".font-semibold", text: @app.name
    end
  end

  describe "sidebar with deployed app" do
    setup do
      @app.update!(status: :active, deployed_at: 1.hour.ago)
    end

    test "shows last deployed time" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "body", /Deployed.*ago/
    end

    test "shows restart quick action" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "form[action='#{project_app_restarts_path(@project, @app)}']"
    end
  end

  describe "sidebar with github repo" do
    setup do
      @app = apps(:smol_roda)
      # smol_roda has a github_repo fixture
    end

    test "shows deploy quick action when github repo is connected" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "form[action='#{project_app_deployments_path(@project, @app)}']"
    end

    test "shows github repo in links section" do
      get project_app_path(@project, @app)

      assert_response :success
      assert_select "a[href='#{@app.github_repo.web_url}']"
    end
  end

  describe "sidebar with linked services" do
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
      assert_select "a[href='#{project_service_metrics_path(@project, @service)}']"
    end
  end
end
