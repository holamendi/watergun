require "test_helper"

class Projects::Apps::EnvVariablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
  end

  test "variable row menu preserves reveal copy lazy edit and confirmed deletion" do
    @app.env_variables.create!(name: "UI_EXAMPLE", value: "example-only")
    get project_app_env_variables_path(@project, @app)
    assert_select "[data-controller='row-actions'] button[aria-haspopup='menu']"
    assert_select "button[role='menuitem'][data-action='secret-field#toggle']", text: "Reveal value"
    assert_select "button[role='menuitem'][data-action='clipboard#copy']", text: "Copy value"
    assert_select "a[role='menuitem'][data-turbo-frame='env_variable_form']", text: "Edit Variable"
    assert_select "a[role='menuitem'][data-turbo-method='delete'][data-turbo-confirm]", text: "Delete Variable"
    assert_select "[data-clipboard-target='status'][role='status']"
  end

  describe "#index" do
    test "renders variables page with settings sidebar" do
      get project_app_env_variables_path(@project, @app)

      assert_response :success
      assert_select "h1", text: "Environment Variables"
      assert_select "nav[aria-label='Settings navigation']"
      assert_select "[data-ui-component='page-header']"
      assert_select "a[data-ui-component='button'][data-turbo-frame='env_variable_form']"
      assert_select "#env_variables_section"
      assert_select "[data-ui-component='empty-state']"
    end
  end
end
