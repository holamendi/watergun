require "test_helper"

class ServerActions::PullEnvTest < ActiveSupport::TestCase
  include SshTestHelper

  test "syncs exported values without saving them in the logs" do
    app = apps(:smol_roda)
    server = app.server
    secret = "pull-env-secret"
    command = Dokku::Config::ExportCommand.new(app: app.dokku_id)
    mock_ssh_session(
      host: server.public_ip,
      user: SshKey::USER,
      port: server.ssh_port,
      private_key: server.ssh_key.private_key,
      commands: [{cmd: command.cmd, stdout: [{name: "API_KEY", value: secret}].to_json}]
    )

    action = ServerActions::PullEnv.run_now!(server, app)

    assert action.success?
    assert_equal secret, app.env_variables.find_by!(name: "API_KEY").value
    logs = action.log.reload.ssh_commands.to_json
    assert_not_includes logs, secret
    assert_includes logs, "[FILTERED]"
  end

  test "invalid export output is left out of the error" do
    command = Dokku::Config::ExportCommand.new(app: "smol-roda")

    error = assert_raises(JSON::ParserError) { command.parse_output(0, "API_KEY=pull-env-secret") }

    assert_not_includes error.message, "pull-env-secret"
    assert_nil error.cause
  end
end
