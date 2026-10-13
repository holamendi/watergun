require "test_helper"

class Ssh::SessionTest < ActiveSupport::TestCase
  include SshTestHelper

  setup do
    @host = "123.45.67.89"
    @user = "user"
    @private_key = "private-key"
    @port = 22

    @session = Ssh::Session.new(
      host: @host,
      user: @user,
      private_key: @private_key,
      port: @port
    )
  end

  def mock_session(commands = [])
    mock_ssh_session(
      host: @host,
      user: @user,
      port: @port,
      private_key: @private_key,
      commands:
    )
  end

  test "config set failures filter unsaved streaming output and failure messages" do
    secret = "failed_set_stream_test_secret"
    command = Dokku::Config::SetCommand.new(app: "app", env: {"API_KEY" => secret})
    mock_session [{cmd: command.cmd, stdout: secret, stderr: Base64.strict_encode64(secret), exit_code: 1}]
    streamed = []

    @session.connect do |ssh|
      ssh.execute(command, save_output: false) { |stream, data| streamed << [stream, data] }
    end

    refute_includes streamed.to_json, secret
    refute_includes streamed.to_json, Base64.strict_encode64(secret)
    assert streamed.all? { |_, data| data == "[FILTERED]" }
    assert_empty @session.commands.first.output
    refute_includes Ssh::CommandExecutionError.new(@session.commands.first).message, Base64.strict_encode64(secret)
  end

  test "sensitive output streams are filtered while exports remain parseable" do
    secret = "ssh_stream_regression_secret"
    command = Dokku::Config::ExportCommand.new(app: "app")
    values = [{"name" => "API_KEY", "value" => secret}]
    mock_session [{cmd: command.cmd, stdout: values.to_json, stderr: "warning #{secret}"}]
    streamed = []
    result = nil

    @session.connect do |ssh|
      result = ssh.execute(command) { |stream, data| streamed << [stream, data] }
    end

    refute_includes streamed.to_json, secret
    assert_equal values, result.parsed_output
    assert_equal %i[stdout stderr], streamed.map(&:first)
    assert streamed.all? { |_, data| data == "[FILTERED]" }
  end

  describe "#connect" do
    test "connects with correct SSH parameters" do
      mock_session

      @session.connect {}
    end

    test "sets timestamps during connection" do
      mock_session

      freeze_time do
        @session.connect {}

        assert_equal Time.current, @session.started_at
        assert_equal Time.current, @session.finished_at
      end
    end

    test "handles connection errors" do
      Net::SSH.expects(:start).raises(Net::SSH::AuthenticationFailed)

      assert_raises Net::SSH::AuthenticationFailed do
        @session.connect { |_s| }
      end

      assert_not_nil @session.finished_at
    end
  end

  describe "#execute" do
    test "executes command and captures output" do
      cmd = "ls -la"
      stdout = "command output"
      exit_code = 0

      commands = [
        {cmd:, stdout:, stderr: [], exit_code:}
      ]

      mock_session(commands)

      @session.connect do |ssh|
        @result = ssh.execute(cmd)
      end

      assert_instance_of Ssh::Command, @result
      assert @result.success?
      assert_equal cmd, @result.cmd
      assert_equal stdout, @result.text_output
      assert_equal [@result], @session.commands
    end

    test "streams output when block given" do
      cmd = "ls -la"
      stdout = "command output\n"

      mock_session [
        {cmd:, stdout:}
      ]

      @session.connect do |ssh|
        ssh.execute(cmd) do |stream, data|
          @output_stream = [stream, data]
        end
      end

      assert_equal [:stdout, stdout], @output_stream
    end
  end

  test "does not save output when save_output is false" do
    cmd = "ls -la"
    stdout = "command output\n"

    mock_session [
      {cmd:, stdout:}
    ]

    result = nil
    @session.connect do |ssh|
      result = ssh.execute(cmd, save_output: false)
    end

    assert_empty result.output
  end

  describe "#execute!" do
    test "does not raise error on command success" do
      cmd = "ls"

      mock_session [
        {cmd:, exit_code: 0}
      ]

      @session.connect do |ssh|
        @result = ssh.execute!(cmd)
      end

      assert @result.success?
      assert @session.success?
      assert_equal cmd, @result.cmd
    end

    test "raises error on command failure" do
      cmd = "invalid-command"
      exit_code = 1

      mock_session [
        {cmd:, exit_code:}
      ]

      error = assert_raises Ssh::CommandExecutionError do
        @session.connect do |ssh|
          ssh.execute!(cmd)
        end
      end

      assert_equal cmd, error.ssh_command.cmd
      assert_equal exit_code, error.ssh_command.exit_code
      assert_equal "command failed with status #{exit_code}: #{cmd}", error.message
    end
  end
end
