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
  #       cmd: "ls -la",
  #       stdout: [
  #         "total 24",
  #         "drwxr-xr-x 6 root root 4096 Feb 10 12:00 dokku",
  #         "drwxr-xr-x 3 root root 4096 Feb 10 12:00 git"
  #       ],
  #       exit_code: 0
  #     }
  #   ]
  # )
  #
  def mock_ssh_session(host:, user:, port:, private_key:, commands: [])
    session = mock
    channel = mock

    commands.each do |config|
      cmd = config[:cmd]
      stdout = Array(config[:stdout]).compact
      stderr = Array(config[:stderr]).compact
      exit_code = config[:exit_code] || 0

      session.expects(:exec!).with do |exec_cmd, opts|
        opts[:status][:exit_code] = exit_code if exec_cmd == cmd
      end.multiple_yields(
        *stdout.map { [channel, :stdout, it] },
        *stderr.map { [channel, :stderr, it] }
      )
    end

    session.expects(:loop)

    Net::SSH.expects(:start)
      .with(host, user,
        port:,
        key_data: [private_key],
        keys_only: true,
        non_interactive: true)
      .yields(session)
  end
end
