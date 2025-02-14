require "test_helper"

class ServerActions::CreateAppTest < ActiveSupport::TestCase
  include SshTestHelper

  def setup
    @app = apps(:smol_roda)
    @server = @app.server
    @server.create_ssh_key!
  end

  test "creates a dokku app" do
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {
          cmd: "dokku apps:create smol-roda"
        },
        {
          cmd: "dokku domains:report smol-roda",
          stdout: file_fixture("dokku/domains/report_command_output.txt").read
        }
      ]
    )

    action = ServerActions::CreateApp.run_now!(@app.server, @app)

    assert action.persisted?
    assert action.success?
  end
end
