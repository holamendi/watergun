require "test_helper"

class Projects::Apps::EnvVariablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
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
