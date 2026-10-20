module SshTestHelper
  # usage example:
  #
  # mock_ssh_session(
  #   host: "123.456.789.0",
  #   user: "root",
  #   port: 22,
  #   private_key_data: "abc-123",
  #   commands: [
  #     {
  #       cmd: "ls",
  #       stdout: "output 1\noutput 2\n",
  #       exit_code: 0
  #     }
  #   ]
  # )
  #
  def mock_ssh_session(host:, user:, port:, private_key:, commands: [], ordered: false)
    session = mock
    channel = mock

    command_order = sequence("ssh commands") if ordered
    commands.each do |config|
      cmd = config[:cmd]
      stdout = Array(config[:stdout]).compact
      stderr = Array(config[:stderr]).compact
      exit_code = config[:exit_code] || 0

      expectation = session.expects(:exec!)
      expectation.in_sequence(command_order) if ordered
      expectation.with do |exec_cmd, opts|
        opts[:status][:exit_code] = exit_code if exec_cmd == cmd
      end.multiple_yields(
        *stdout.map { [channel, :stdout, it] },
        *stderr.map { [channel, :stderr, it] }
      )
    end

    session.expects(:loop).at_least_once

    Net::SSH.expects(:start)
      .with(host, user, ssh_connection_options(port:, private_key:))
      .yields(session)
  end

  def ssh_connection_options(port:, private_key:)
    {
      port:,
      key_data: [private_key],
      keys_only: true,
      non_interactive: true,
      timeout: 10,
      keepalive: true,
      keepalive_interval: 15,
      keepalive_maxcount: 3
    }
  end
end
