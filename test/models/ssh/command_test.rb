require "test_helper"
require_relative "../../../app/models/ssh/session"

class Ssh::CommandTest < ActiveSupport::TestCase
  test "invalid config export errors do not include secret output" do
    secret = "invalid_export_regression_secret"
    command = Ssh::Command.new(Dokku::Config::ExportCommand.new(app: "app"))
    command.append_output(:stdout, "not-json-#{secret}")
    command.finish(0)

    error = assert_raises(JSON::ParserError) { command.parsed_output }
    refute_includes error.message, secret
    assert_nil error.cause
    assert_includes error.message, "[FILTERED]"
  end

  test "config set echoed values are excluded from output logs" do
    secret = "config_set_echo_regression_secret"
    command = Ssh::Command.new(Dokku::Config::SetCommand.new(app: "app", env: {"API_KEY" => secret}))
    command.append_output(:stdout, "API_KEY=#{secret}")
    command.append_output(:stderr, Base64.strict_encode64(secret))
    command.finish(1)

    refute_includes command.as_json.to_json, secret
    refute_includes command.as_json.to_json, Base64.strict_encode64(secret)
    assert_includes command.text_output, "[FILTERED]"
  end

  test "config export remains parseable without exposing either output stream in logs" do
    secret = "export_output_regression_secret"
    values = [{"name" => "API_KEY", "value" => secret}]
    command = Ssh::Command.new(Dokku::Config::ExportCommand.new(app: "app"))
    command.append_output(:stdout, values.to_json)
    command.append_output(:stderr, "warning #{secret}")
    command.finish(0)

    assert_equal values, command.parsed_output
    refute_includes command.as_json.to_json, secret
    refute_includes command.text_output, secret
    refute_includes command.output.map(&:data).join, secret
    assert_includes command.text_output, "[FILTERED]"
  end

  test "config set values are executed but omitted from serialized commands and failures" do
    secret = "config_set_regression_secret"
    command = Ssh::Command.new(Dokku::Config::SetCommand.new(app: "app", env: {"API_KEY" => secret}))
    command.finish(1)

    assert_includes command.cmd, Base64.encode64(secret)
    refute_includes command.as_json.to_json, Base64.encode64(secret).strip
    refute_includes Ssh::CommandExecutionError.new(command).message, Base64.encode64(secret).strip
    assert_includes command.as_json[:cmd], "[FILTERED]"
  end

  test "structured command parsing excludes stderr but retains it in logs" do
    command = Ssh::Command.new(Dokku::Storage::ListCommand.new(app: "app", phase: "deploy"))
    command.append_output(:stdout, [{entry: {name: "legacy-123", host_path: "/host", scheduler: "docker-local"}, attachment: {entry_name: "legacy-123", container_path: "/data"}}].to_json)
    warning = " !     Deprecated: please use the 'storage-app-mounts' plugin trigger instead of 'storage-list'\n"
    command.append_output(:stderr, warning)
    command.finish(0)

    assert_equal [{"entry_name" => "legacy-123", "host_path" => "/host", "container_path" => "/data", "scheduler" => "docker-local"}], command.parsed_output
    assert_includes command.text_output, warning
    assert_includes command.as_json.to_json, "Deprecated"
  end

  test "structured command parsing joins stdout chunks in order" do
    command = Ssh::Command.new(Dokku::Storage::ListCommand.new(app: "app", phase: "run"))
    command.append_output(:stdout, "[")
    command.append_output(:stderr, "warning\n")
    command.append_output(:stdout, "]\n")
    command.finish(0)

    assert_equal [], command.parsed_output
  end

  test "structured command parsing still rejects invalid stdout" do
    command = Ssh::Command.new(Dokku::Storage::ListCommand.new(app: "app", phase: "run"))
    command.append_output(:stdout, "not JSON")
    command.finish(0)

    assert_raises(JSON::ParserError) { command.parsed_output }
  end

  test "raw shell commands retain combined output" do
    command = Ssh::Command.new("echo output")
    command.append_output(:stdout, "output\n")
    command.append_output(:stderr, "warning\n")
    command.finish(0)

    assert_equal "output\nwarning\n", command.parsed_output
  end

  test "GitHub authentication failures do not expose the token" do
    token = "installation_token_for_error_redaction_test"
    command = Ssh::Command.new(Dokku::Git::AuthCommand.new(access_token: token))
    command.finish(1)
    message = Ssh::CommandExecutionError.new(command).message

    refute_includes message, token
    assert_includes message, "[FILTERED]"
  end
  test "GitHub authentication token is used for execution but not serialized into logs" do
    token = "installation_token_for_redaction_test"
    command = Ssh::Command.new(Dokku::Git::AuthCommand.new(access_token: token))

    assert_equal "dokku git:auth github.com u #{token}", command.cmd
    assert_equal "dokku git:auth github.com u [FILTERED]", command.as_json[:cmd]
    refute_includes command.as_json.to_json, token
  end
end
