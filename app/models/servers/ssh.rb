module Servers
  class Ssh
    attr_reader :server, :ssh_connection, :ssh_commands, :success, :started_at, :completed_at

    def initialize(server:)
      @server = server
      @ssh_connection = nil
      @ssh_commands = []
      @success = true
    end

    def connection
      @started_at = Time.current

      Net::SSH.start(server.public_ip, Server::USER, key_data: [server.ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
        @ssh_connection = ssh
        yield(self) if block_given?
      end

      @completed_at = Time.current
      @ssh_connection = nil
      self
    end

    def execute(command)
      ssh_command = SshCommand.new(command:, started_at: Time.current)
      @ssh_commands << ssh_command
      status = {}

      ssh_connection.exec!(command) do |_channel, stream, data|
        ssh_command.output << [stream, data]
        yield(stream.to_s, data) if block_given?
      end

      ssh_command.completed_at = Time.current
      ssh_command.exit_code = status[:exit_code]
      ssh_command
    end

    def success?
      success
    end
  end
end
