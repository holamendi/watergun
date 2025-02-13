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
