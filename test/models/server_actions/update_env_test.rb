require "test_helper"

class ServerActions::UpdateEnvTest < ActiveSupport::TestCase
  include SshTestHelper

  setup do
    @app = apps(:smol_roda)
    @server = @app.server
  end

  test "env values are encrypted at rest" do
    action = ServerActions::UpdateEnv.create!(server: @server, actionable: @app, set: {"API_KEY" => "update-env-secret"}, unset: ["OLD_KEY"])

    assert_not_includes raw_payload(action), "update-env-secret"

    action = ServerAction.find(action.id)
    assert_equal({"API_KEY" => "update-env-secret"}, action.set)
    assert_equal ["OLD_KEY"], action.unset
    assert_equal @app.dokku_id, action.dokku_app_id
  end

  test "plaintext payloads saved before encryption stay readable" do
    action = ServerActions::UpdateEnv.create!(server: @server, actionable: @app)
    ServerAction.where(id: action.id).update_all(payload: {dokku_app_id: @app.dokku_id, set: {"API_KEY" => "legacy-secret"}.to_json, unset: ["OLD_KEY"].to_json, restart: false})

    action = ServerAction.find(action.id)
    assert_equal({"API_KEY" => "legacy-secret"}, action.set)
    assert_equal ["OLD_KEY"], action.unset
  end

  test "displayed payload hides env values" do
    action = ServerActions::UpdateEnv.new(server: @server, actionable: @app, set: {"API_KEY" => "update-env-secret"})

    assert_equal({"API_KEY" => "[FILTERED]"}, action.displayed_payload["set"])
  end

  test "saved logs omit env values" do
    secret = "update-env-secret"
    command = Dokku::Config::SetCommand.new(app: @app.dokku_id, env: {"API_KEY" => secret})
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [{cmd: command.cmd, stdout: "-----> Setting config vars\n       API_KEY:  #{secret}\n"}]
    )

    action = ServerActions::UpdateEnv.run_now!(@server, @app, set: {"API_KEY" => secret})

    assert action.success?
    logs = action.log.reload.ssh_commands.to_json
    assert_not_includes logs, secret
    assert_not_includes logs, Base64.encode64(secret).strip
    assert_includes logs, "API_KEY=[FILTERED]"
  end

  private

  def raw_payload(action)
    ServerAction.connection.select_value("SELECT payload FROM server_actions WHERE id = #{action.id.to_i}")
  end
end
