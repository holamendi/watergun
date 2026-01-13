require "test_helper"

class ServerActions::RestartAppTest < ActiveSupport::TestCase
  include SshTestHelper

  setup do
    @app = apps(:smol_roda)
    @server = @app.server

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [{cmd: "dokku ps:restart #{@app.dokku_id}"}]
    )
  end

  test "restarts the dokku app" do
    server_action = ServerActions::RestartApp.run_now!(@server, @app)

    assert server_action.success?
    assert @app.active?
  end
end
