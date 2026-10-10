require "test_helper"
require_relative "../../../app/models/ssh/session"

class Ssh::CommandTest < ActiveSupport::TestCase
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
