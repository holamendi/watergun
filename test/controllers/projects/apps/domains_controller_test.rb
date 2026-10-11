require "test_helper"

class Projects::Apps::DomainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
  end

  test "domain rows use a native accessible shared actions menu" do
    @app.domains.create!(hostname: "ui.example.com")
    get project_app_domains_path(@project, @app)
    assert_select "[data-controller='row-actions'] button[type='button'][aria-haspopup='menu'][aria-expanded='false']"
    assert_select "[role='menu'][popover='manual'] a[role='menuitem'][data-turbo-method='delete'][data-turbo-confirm]"
    assert_select "div[role='button']", count: 0
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
