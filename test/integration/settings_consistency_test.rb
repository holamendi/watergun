require "test_helper"

class SettingsConsistencyTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @app = apps(:domain_test_app)
    sign_in users(:bobby)
  end

  test "settings add actions and modal close controls share configuration roles" do
    [project_app_domains_path(@project, @app), project_app_storage_mounts_path(@project, @app), project_app_env_variables_path(@project, @app)].each do |path|
      get path
      assert_select "[data-ui-component='page-header'] .config-action-primary"
      assert_select "dialog form[method='dialog'] button.config-icon.config-action-compact[aria-label='Close dialog']"
    end
    get new_project_app_env_variable_path(@project, @app)
    assert_select "form[method='dialog'] button.config-icon"
  end

  test "general settings preserve three independent scoped saves with consistent geometry" do
    get project_app_settings_path(@project, @app)
    assert_response :success
    %w[app_form github_repo_form builder_form].each do |id|
      assert_select "form##{id}.config-settings-form" do
        assert_select ".config-form-footer button.config-action[type='submit']", count: 1
      end
    end
    assert_select "#danger-zone a.config-action[data-turbo-method='delete'][data-turbo-confirm]"
    assert_select "form.config-settings-form", count: 3
  end

  test "configuration dialogs share explicit cancel and submit footers including lazy forms" do
    [project_app_domains_path(@project, @app), project_app_storage_mounts_path(@project, @app), new_project_app_env_variable_path(@project, @app)].each do |path|
      get path
      assert_response :success
      assert_select ".config-modal-footer" do
        assert_select "button.config-action-compact[type='button'][data-action='dialog#close']", text: "Cancel"
        assert_select "button.config-action-primary[type='submit']"
      end
    end
    variable = @app.env_variables.create!(name: "UI_FORM", value: "example-only")
    get edit_project_app_env_variable_path(@project, @app, variable)
    assert_select "turbo-frame#env_variable_form .config-modal-footer"
    assert_select "input[name='env_variable[name]'][readonly]"
  end
end
