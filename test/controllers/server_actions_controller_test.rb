require "test_helper"

class ServerActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @server = servers(:arm)
    sign_in users(:bobby)
  end

  test "history payload display redacts environment values" do
    project = @server.projects.create!(name: "History test")
    app = project.apps.create!(name: "History app", server: @server)
    run = ServerAction::Enqueue.call(action: "apps.update_env", target: app, payload: {set: {"API_KEY" => "history-test-secret"}})
    get server_action_url(run)
    assert_response :success
    refute_includes response.body, "history-test-secret"
    assert_includes response.body, "[FILTERED]"
  end

  describe "#index" do
    test "lists server actions for the current server" do
      get server_actions_url
      assert_response :success
    end
  end

  describe "#show" do
    test "displays server action details" do
      server_action = server_action_runs(:deploy_success)
      get server_action_url(server_action)
      assert_response :success
      assert_select "a[data-ui-component='back-link'][href='#{server_actions_path}']"
      assert_select "[data-ui-component='page-header']"
      assert_select ".log-panel"
    end

    test "displays failed server action with failure message" do
      server_action = server_action_runs(:deploy_failed)
      get server_action_url(server_action)
      assert_response :success
      assert_includes response.body, server_action.failure_message
    end

    test "displays running server action" do
      server_action = server_action_runs(:deploy_running)
      get server_action_url(server_action)
      assert_response :success
      assert_includes response.body, "Waiting for action to complete"
    end

    test "returns 404 for server action from another account" do
      server_action = server_action_runs(:other_account_action)
      get server_action_url(server_action)
      assert_response :not_found
    end
  end
end
