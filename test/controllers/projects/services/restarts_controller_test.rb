require "test_helper"

class Projects::Services::RestartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @service = services(:redis)
    @project = @service.project
    @server = @service.server
    @user = @service.account.users.first

    sign_in @user
  end

  test "schedules a restart for the service" do
    post project_service_restarts_url(project_id: @project.id, service_id: @service.id)

    assert_server_action_scheduled(
      ServerActions::RestartService,
      server: @server,
      actionable: @service,
      payload: {dokku_service_id: @service.dokku_id, service_type: @service.service_type}
    )
  end
end
