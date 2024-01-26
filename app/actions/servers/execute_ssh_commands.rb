module Servers
  class ExecuteSshCommands
    attr_reader :server, :ssh_commands, :success, :started_at, :completed_at

    def initialize(server:, commands:)
      @server = server
      @ssh_commands = Array.wrap(commands).map { |command| SshCommand.new(command:) }
      @success = true
    end

    def call
      @started_at = Time.current

      Net::SSH.start(server.public_ip, Server::USER, key_data: [server.ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
        ssh_commands.each_with_index do |ssh_command, index|
          ssh_command.started_at = Time.current
          status = {}

          ssh.exec!(ssh_command.command, status:) do |_channel, _stream, data|
            ssh_command.output << data
            yield(data) if block_given?
          end

          ssh_command.completed_at = Time.current
          ssh_command.exit_code = status[:exit_code]

          if ssh_command.failure?
            @success = false
            break
          end
        end
      end

      @completed_at = Time.current
      self
    end

    def success?
      success
    end
  end
end
