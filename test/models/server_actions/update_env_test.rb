require "test_helper"

class ServerActions::UpdateEnvTest < ActiveSupport::TestCase
  include SshTestHelper

  test "sibling action payloads retain their existing JSON storage" do
    app = apps(:smol_roda)
    action = ServerActions::RestartApp.create!(server: app.server, actionable: app)

    raw = ServerAction.connection.select_value("SELECT payload FROM server_actions WHERE id = #{action.id.to_i}")
    assert_equal({"dokku_app_id" => app.dokku_id}, JSON.parse(raw))
    assert_equal app.dokku_id, ServerAction.find(action.id).dokku_app_id
  end

  test "legacy plaintext payloads remain readable and encrypt on payload rewrite" do
    app = apps(:smol_roda)
    action = ServerActions::UpdateEnv.create!(server: app.server, actionable: app)
    payload = {"dokku_app_id" => app.dokku_id, "set" => {"API_KEY" => "legacy_test_secret"}.to_json, "unset" => ["OLD_KEY"].to_json, "restart" => false}
    ServerAction.where(id: action.id).update_all(payload: payload)

    loaded = ServerAction.find(action.id)
    assert_instance_of ServerActions::UpdateEnv, loaded
    assert_equal({"API_KEY" => "legacy_test_secret"}, loaded.set)
    assert_equal ["OLD_KEY"], loaded.unset
    loaded.update!(set: {"API_KEY" => "rewritten_test_secret"})
    raw = ServerAction.connection.select_value("SELECT payload FROM server_actions WHERE id = #{action.id.to_i}")
    refute_includes raw.to_s, "rewritten_test_secret"
    assert_equal({"API_KEY" => "rewritten_test_secret"}, loaded.reload.set)
  end

  test "reloaded queued actions execute secrets but persist only filtered logs" do
    app = apps(:smol_roda)
    secret = "queued_execution_test_secret"
    action = ServerActions::UpdateEnv.create!(server: app.server, actionable: app, set: {"API_KEY" => secret})
    command = Dokku::Config::SetCommand.new(app: app.dokku_id, env: {"API_KEY" => secret})
    mock_ssh_session(host: app.server.public_ip, user: SshKey::USER, port: app.server.ssh_port, private_key: app.server.ssh_key.private_key,
      commands: [{cmd: command.cmd, stdout: secret, stderr: Base64.strict_encode64(secret)}])

    RunServerActionJob.perform_now(ServerAction.find(action.id))

    assert action.reload.success?
    refute_includes action.log.reload.ssh_commands.to_json, secret
    refute_includes action.log.ssh_commands.to_json, Base64.strict_encode64(secret)
    assert_includes action.log.ssh_commands.to_json, "[FILTERED]"
    assert_server_action_scheduled(ServerActions::PullEnv, server: app.server, actionable: app, payload: {dokku_app_id: app.dokku_id})
  end

  test "queued environment values are encrypted at rest and restored for execution" do
    app = apps(:smol_roda)
    secret = "env_payload_regression_secret"
    action = ServerActions::UpdateEnv.create!(server: app.server, actionable: app, set: {"API_KEY" => secret}, unset: ["OLD_KEY"], restart: true)

    raw = ServerAction.connection.select_value("SELECT payload FROM server_actions WHERE id = #{action.id.to_i}")
    refute_includes raw.to_s, secret
    action.reload
    assert_equal({"API_KEY" => secret}, action.set)
    assert_equal ["OLD_KEY"], action.unset
    assert action.restart
    assert_equal app.dokku_id, action.dokku_app_id
  end
end
