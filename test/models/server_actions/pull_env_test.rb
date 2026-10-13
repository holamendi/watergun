require "test_helper"

class ServerActions::PullEnvTest < ActiveSupport::TestCase
  include SshTestHelper

  test "exported values are synced encrypted without persisting plaintext command output" do
    app = apps(:smol_roda)
    secret = "pull_env_sync_test_secret"
    values = [{name: "API_KEY", value: secret}]
    command = Dokku::Config::ExportCommand.new(app: app.dokku_id)
    mock_ssh_session(host: app.server.public_ip, user: SshKey::USER, port: app.server.ssh_port, private_key: app.server.ssh_key.private_key,
      commands: [{cmd: command.cmd, stdout: values.to_json, stderr: "warning #{secret}"}])

    action = ServerActions::PullEnv.run_now!(app.server, app)

    assert action.reload.success?
    variable = app.env_variables.find_by!(name: "API_KEY")
    assert_equal secret, variable.value
    raw = EnvVariable.connection.select_value("SELECT value FROM env_variables WHERE id = #{variable.id.to_i}")
    refute_includes raw, secret
    refute_includes action.log.reload.ssh_commands.to_json, secret
    assert_includes action.log.ssh_commands.to_json, "[FILTERED]"
  end
end
