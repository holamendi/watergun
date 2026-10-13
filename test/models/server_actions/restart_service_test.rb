require "test_helper"

class ServerActions::RestartServiceTest < ActiveSupport::TestCase
  include SshTestHelper

  setup do
    @service = services(:redis)
    @server = @service.server

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [{cmd: "dokku #{@service.service_type}:restart #{@service.dokku_id}"}]
    )
  end

  test "restarts the dokku service" do
    server_action = perform_server_action(ServerActions::RestartService, @server, @service)

    assert server_action.success?
    assert @service.active?
  end

  test "notifies user when restart completes" do
    user = users(:bobby)
    Current.user = user

    Toast.expects(:append_to_user).with(user, "#{@service.name}: restart finished")

    perform_server_action(ServerActions::RestartService, @server, @service)
  end
end
