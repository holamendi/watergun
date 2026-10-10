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
    test "renders the service name" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "title", /#{Regexp.escape(@service.name)}/
      assert_select "[data-ui-component='page-header']"
    end

    test "renders the service type" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "body", /#{@service.service_type.to_s.titleize}/
      assert_select "[data-ui-component='empty-state']"
    end

    test "shows unknown instead of error when an active service has no container observations" do
      @service.update!(status: :active)

      get project_service_path(@project, @service)

      assert_response :success
      assert_select ".service-info-card", text: /Status/ do
        assert_select "span", text: "Unknown"
        assert_select ".text-error", count: 0
      end
    end

    %i[pending stopped error].each do |status|
      test "preserves #{status} status without container observations" do
        @service.update!(status: status)

        get project_service_path(@project, @service)

        assert_response :success
        assert_select ".service-info-card", text: /Status/ do
          assert_select "span", text: status.to_s.titleize
        end
      end
    end

    test "shows running for an observed running service container" do
      @service.update!(status: :active)
      @service.containers.create!(
        server: @service.server,
        cid: "postgres-running",
        name: "dokku.postgres.#{@service.dokku_id}",
        checked_at: Time.current,
        cpu_percentage: 0,
        memory_percentage: 0,
        status: :running
      )

      get project_service_path(@project, @service)

      assert_response :success
      assert_select ".service-info-card", text: /Status/ do
        assert_select "span.text-success", text: "Running"
      end
    end

    test "renders navigation tabs" do
      get project_service_path(@project, @service)

      assert_response :success

      assert_select "a[href='#{project_service_path(@project, @service)}']"
      assert_select "a[href='#{project_service_metrics_path(@project, @service)}']"
      assert_select "a[href='#{project_service_log_streams_path(@project, @service)}']"
    end

    test "renders back link to project" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "a[href='#{project_path(@project)}']", text: /#{@project.name}/
    end

    test "renders settings link" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "a[href='#{edit_project_service_path(@project, @service)}']"
    end
  end

  describe "#edit" do
    test "renders the edit form" do
      get edit_project_service_path(@project, @service)

      assert_response :success
      assert_select "input[name='service[name]'][value='#{@service.name}']"
      assert_select "[data-ui-component='danger-zone']"
      assert_select "a[data-ui-component='button'][data-turbo-method='delete'][href='#{project_service_path(@project, @service)}']"
    end
  end

  describe "active service" do
    setup do
      @service.update!(status: :active)
    end
  end

  describe "pending service" do
    setup do
      @service.update!(status: :pending)
    end

    test "does not show restart action" do
      get project_service_path(@project, @service)

      assert_response :success
      assert_select "form[action='#{project_service_restarts_path(@project, @service)}']", count: 0
    end
  end

  describe "service with linked apps" do
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
