require "test_helper"

class Projects::Apps::DomainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
  end

  describe "#index" do
    test "renders domains page with settings sidebar" do
      get project_app_domains_path(@project, @app)

      assert_response :success
      assert_select "h1", text: "Domains"
      assert_select "nav[aria-label='Settings navigation']"
      assert_select "[data-ui-component='page-header']"
      assert_select "button[data-ui-component='modal-trigger']"
      assert_select "#domains"
      assert_select "[data-ui-component='empty-state']"
    end
  end
end
