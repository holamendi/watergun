require "test_helper"

class Projects::Apps::BuildersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @app = apps(:smol_roda)
    @app.update!(builder: "herokuish")
    sign_in users(:bobby)
  end

  test "builder change rolls back when action validation fails" do
    original = @app.builder
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) do
        patch project_app_builder_path(@app.project, @app), params: {app: {builder: "dockerfile"}}, as: :turbo_stream
      end
    end
    assert_equal original, @app.reload.builder
  end

  test "builder form uses the shared registered action path" do
    patch project_app_builder_path(@app.project, @app), params: {app: {builder: "dockerfile"}}, as: :turbo_stream
    assert_response :success
    assert_equal "dockerfile", @app.reload.builder
    assert_server_action_scheduled("apps.set_builder", server: @app.server, target: @app,
      payload: {builder: "dockerfile"})
  end
end
