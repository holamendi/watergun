require "test_helper"

class ServerActions::UpdateEnvTest < ActiveSupport::TestCase
  include SshTestHelper

  test "sibling action payloads are encrypted and retain their JSON values" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.restart", server: app.server, target: app)
    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{action.id.to_i}")
    refute_includes raw, app.dokku_id
    assert_equal app.dokku_id, ServerActionRun.find(action.id).payload.fetch("dokku_app_id")
  end

  test "JSON payload rewrite preserves structured values and encryption" do
    app = apps(:smol_roda)
    action = create_server_action_run("apps.update_env", server: app.server, target: app)
    payload = {"dokku_app_id" => app.dokku_id, "set" => {"API_KEY" => "legacy_test_secret"}, "unset" => ["OLD_KEY"], "restart" => false}
    action.update!(payload: payload)
    loaded = ServerActionRun.find(action.id)
    assert_instance_of ServerActionRun, loaded
    assert_equal({"API_KEY" => "legacy_test_secret"}, loaded.payload["set"])
    assert_equal ["OLD_KEY"], loaded.payload["unset"]
    loaded.update!(payload: loaded.payload.merge("set" => {"API_KEY" => "rewritten_test_secret"}))
    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{action.id.to_i}")
    refute_includes raw.to_s, "rewritten_test_secret"
    assert_equal({"API_KEY" => "rewritten_test_secret"}, loaded.reload.payload["set"])
  end

  test "reloaded queued actions execute secrets but persist only filtered logs" do
    app = apps(:smol_roda)
    secret = "queued_execution_test_secret"
    action = create_server_action_run("apps.update_env", server: app.server, target: app, set: {"API_KEY" => secret})
    command = Dokku::Config::SetCommand.new(app: app.dokku_id, env: {"API_KEY" => secret})
    mock_ssh_session(host: app.server.public_ip, user: SshKey::USER, port: app.server.ssh_port, private_key: app.server.ssh_key.private_key,
      commands: [{cmd: command.cmd, stdout: secret, stderr: Base64.strict_encode64(secret)}])

    RunServerActionJob.perform_now(action.id, action.resource_key)

    assert action.reload.success?
    refute_includes action.log.reload.ssh_commands.to_json, secret
    refute_includes action.log.ssh_commands.to_json, Base64.strict_encode64(secret)
    assert_includes action.log.ssh_commands.to_json, "[FILTERED]"
    assert_server_action_scheduled("apps.pull_env", server: app.server, target: app, payload: {dokku_app_id: app.dokku_id})
  end

  test "queued environment values are encrypted at rest and restored for execution" do
    app = apps(:smol_roda)
    secret = "env_payload_regression_secret"
    action = create_server_action_run("apps.update_env", server: app.server, target: app, set: {"API_KEY" => secret}, unset: ["OLD_KEY"], restart: true)

    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{action.id.to_i}")
    refute_includes raw.to_s, secret
    action.reload
    assert_equal({"API_KEY" => secret}, action.payload["set"])
    assert_equal ["OLD_KEY"], action.payload["unset"]
    assert action.payload["restart"]
    assert_equal app.dokku_id, action.payload["dokku_app_id"]
  end
end
