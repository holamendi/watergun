require "test_helper"

class Ssh::SessionTest < ActiveSupport::TestCase
  setup do
    @host = "123.45.67.89"
    @user = "user"
    @private_key = "private-key"
    @port = 22

    @ssh_connection = mock
    @ssh_connection.stubs(:loop)
    Net::SSH.stubs(:start).yields(@ssh_connection)

    @session = Ssh::Session.new(
      host: @host,
      user: @user,
      private_key: @private_key,
      port: @port
    )
  end

  describe "#connect" do
    test "connects with correct SSH parameters" do
      Net::SSH.expects(:start).with(
        @host,
        @user,
        port: @port,
        key_data: [@private_key],
        keys_only: true,
        non_interactive: true
      ).yields(@ssh_connection)

      @session.connect {}
    end

    test "sets timestamps during connection" do
      freeze_time do
        @session.connect {}

        assert_equal Time.current, @session.started_at
        assert_equal Time.current, @session.finished_at
      end
    end

    test "handles connection errors" do
      Net::SSH.unstub(:start)
      Net::SSH.expects(:start).raises(Net::SSH::AuthenticationFailed)

      assert_raises Net::SSH::AuthenticationFailed do
        @session.connect { |_s| }
      end
    end

    test "cleans up session on error" do
      Net::SSH.unstub(:start)
      Net::SSH.expects(:start).raises(StandardError)

      assert_raises StandardError do
        @session.connect { |_s| }
      end

      assert_not_nil @session.finished_at
    end
  end

  describe "#execute" do
    test "executes command and captures output" do
      command = "ls -la"
      command_output = "command output\n"
      result = nil

      @ssh_connection.expects(:exec!).with(
        command,
        status: instance_of(Hash)
      ).yields(nil, :stdout, command_output)

      @session.connect do |ssh|
        result = ssh.execute(command)
      end

      result.stubs(:exit_code).returns(0)

      assert_instance_of Ssh::Command, result
      assert result.success?
      assert_equal command, result.command
      assert_equal command_output, result.output.first.data
      assert_equal [result], @session.commands
    end

    test "streams output when block given" do
      command = "ls -la"
      command_output = "command output\n"
      output_received = nil

      @ssh_connection.expects(:exec!).with(
        command,
        status: instance_of(Hash)
      ).yields(nil, :stdout, command_output)

      @session.connect do |ssh|
        ssh.execute(command) do |stream, data|
          output_received = [stream, data]
        end
      end

      assert_equal ["stdout", command_output], output_received
    end
  end

  test "does not save output when save_output is false" do
    command = "ls -la"
    command_output = "command output\n"

    @ssh_connection.expects(:exec!).with(
      command,
      status: instance_of(Hash)
    ).yields(nil, :stdout, command_output)

    result = nil
    @session.connect do |ssh|
      result = ssh.execute(command, save_output: false)
    end

    assert_empty result.output
  end

  describe "#execute!" do
    test "does not raise error on command success" do
      skip "needs work"

      command = "ls"
      result = Ssh::Command.new(command:, started_at: Time.current, finished_at: Time.current, exit_code: 0)
      @session.expects(:execute).with(command, save_output: true).returns(result)

      @session.connect do |ssh|
        result = ssh.execute!(command)
      end

      assert_instance_of Ssh::Command, result
      assert result.success?
      assert_equal command, result.command
    end

    test "raises error on command failure" do
      command = "invalid-command"
      result = Ssh::Command.new(command:, started_at: Time.current, finished_at: Time.current, exit_code: 1)
      @session.expects(:execute).with(command, save_output: true).returns(result)

      error = assert_raises Ssh::CommandExecutionError do
        @session.connect do |ssh|
          ssh.execute!(command)
        end
      end

      assert_equal command, error.command
      assert_equal result, error.result
      assert_equal "command failed with status #{result.exit_code}: #{command}", error.message
    end
  end

  describe "#success?" do
    test "returns true when all commands succeed" do
      @session.expects(:commands).returns([
        Ssh::Command.new(command: "command1", started_at: Time.current, finished_at: Time.current, exit_code: 0),
        Ssh::Command.new(command: "command2", started_at: Time.current, finished_at: Time.current, exit_code: 0)
      ])

      assert @session.success?
    end

    test "returns false when any command fails" do
      @session.expects(:commands).returns([
        Ssh::Command.new(command: "command1", started_at: Time.current, finished_at: Time.current, exit_code: 0),
        Ssh::Command.new(command: "command2", started_at: Time.current, finished_at: Time.current, exit_code: 1)
      ])

      refute @session.success?
    end
  end
end
