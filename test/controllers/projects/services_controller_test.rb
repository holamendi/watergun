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
    test "service navigation reserves a separate mobile metadata row and wraps all tabs" do
      get edit_project_service_path(@project, @service)

      assert_response :success
      assert_select ".app-tabs.flex-col.sm\\:flex-row" do
        assert_select "nav.flex-wrap.sm\\:flex-nowrap[aria-label='Service navigation']" do
          assert_select "a[aria-current='page']", text: "Settings"
          assert_select "a", count: 4
        end
        assert_select ".pb-2.sm\\:pb-0", text: /Postgres/
      end
    end

    test "service settings use shared scoped Save and confirmed compact danger controls" do
      get edit_project_service_path(@project, @service)

      assert_response :success
      assert_select "form.config-settings-form[action='#{project_service_path(@project, @service)}']" do
        assert_select "input[name='service[name]']"
        assert_select ".config-form-footer button.config-action-primary[type='submit']", text: "Save"
      end
      assert_select ".settings-sections .settings-section", count: 2
      assert_select ".danger-zone a.config-action-compact[data-turbo-method='delete'][data-turbo-confirm]", text: "Delete service"
    end

    test "service connection copy uses shared square geometry and honest accessible status" do
      @service.update!(dsn: "postgresql://ui.example.test/example_database")
      get edit_project_service_path(@project, @service)

      assert_response :success
      assert_select ".settings-section", count: 3
      assert_select "[data-controller='clipboard'][data-clipboard-text-value='#{@service.dsn}']" do
        assert_select "button.config-icon.config-action-compact[aria-label='Copy connection string'][data-action='clipboard#copy'][type='button']"
        assert_select "[data-clipboard-target='status'][role='status']"
      end
      assert_select "form.config-settings-form", count: 1
    end

    test "service save response replaces the exact rendered form without widening parameter scope" do
      get edit_project_service_path(@project, @service)
      form_id = css_select("form.config-settings-form").first["id"]

      patch project_service_path(@project, @service), params: {service: {name: "Service UI Example", service_type: "redis"}}, as: :turbo_stream

      assert_response :success
      assert_equal "Service UI Example", @service.reload.name
      assert_equal "postgres", @service.service_type
      assert_select "turbo-stream[action='replace'][target='#{form_id}'] form##{form_id}.config-settings-form"
      assert_select "button.config-action-primary[type='submit']", text: "Save"
    end

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
