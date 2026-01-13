require "test_helper"

class Projects::Apps::RestartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @app = apps(:smol_roda)
    @project = @app.project
    @server = @app.server
    @user = @app.account.users.first

    sign_in @user
  end

  test "schedules a restart for the app" do
    post project_app_restarts_url(project_id: @project.id, app_id: @app.id)

    assert_server_action_scheduled(
      ServerActions::RestartApp,
      server: @server,
      actionable: @app,
      payload: {dokku_app_id: @app.dokku_id}
    )
  end
end
