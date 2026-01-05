require "test_helper"

class ServerActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @server = servers(:arm)
    sign_in users(:bobby)
  end

  describe "#index" do
    test "lists server actions for the current server" do
      get server_actions_url
      assert_response :success
    end
  end

  describe "#show" do
    test "displays server action details" do
      server_action = server_actions(:deploy_success)
      get server_action_url(server_action)
      assert_response :success
    end

    test "displays failed server action with failure message" do
      server_action = server_actions(:deploy_failed)
      get server_action_url(server_action)
      assert_response :success
      assert_includes response.body, server_action.failure_message
    end

    test "displays running server action" do
      server_action = server_actions(:deploy_running)
      get server_action_url(server_action)
      assert_response :success
      assert_includes response.body, "Waiting for action to complete"
    end

    test "returns 404 for server action from another account" do
      server_action = server_actions(:other_account_action)
      get server_action_url(server_action)
      assert_response :not_found
    end
  end
end
