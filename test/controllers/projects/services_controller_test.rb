require "test_helper"

class Projects::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @project = projects(:default)
    @service = services(:postgres)
    @user = users(:bobby)

    sign_in @user
  end

  describe "#show" do
    test "renders the sidebar with service context" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select ".font-semibold", text: @service.name
    end

    test "renders the sidebar with service type" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "body", /#{@service.service_type.to_s.titleize}/
    end

    test "renders the sidebar with server name" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "body", /on #{@service.server.name}/
    end

    test "renders navigation links" do
      get project_service_path(@project, @service)

      assert_response :success

      assert_select "a[href='#{project_service_metrics_path(@project, @service)}']"
      assert_select "a[href='#{project_service_log_streams_path(@project, @service)}']"
      assert_select "a[href='#{edit_project_service_path(@project, @service)}']"
    end

    test "renders back link to project" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "a[href='#{project_path(@project)}']", text: /#{@project.name}/
    end
  end

  describe "#edit" do
    test "renders the sidebar with service context" do
      get edit_project_service_path(@project, @service)

      assert_response :success
      assert_select ".font-semibold", text: @service.name
    end
  end

  describe "sidebar with active service" do
    setup do
      @service.update!(status: :active)
    end

    test "shows restart quick action" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "form[action='#{project_service_restarts_path(@project, @service)}']"
    end
  end

  describe "sidebar with pending service" do
    setup do
      @service.update!(status: :pending)
    end

    test "does not show restart quick action" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "form[action='#{project_service_restarts_path(@project, @service)}']", count: 0
    end
  end

  describe "sidebar with linked apps" do
    setup do
      @app = apps(:smol_roda)
      @service.update!(status: :active)
      env_var = @app.env_variables.create!(name: "DATABASE_URL", value: "postgres://localhost/test")
      ServiceLink.create!(app: @app, service: @service, env_variable: env_var)
    end

    test "shows linked apps section" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "body", /Linked Apps/
      assert_select "a[href='#{project_app_deployments_path(@project, @app)}']"
    end
  end
end
