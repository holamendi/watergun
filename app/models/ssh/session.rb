module Ssh
  class Session
    attr_reader :server, :commands, :started_at, :completed_at

    def initialize(server:)
      @server = server
      @commands = []
    end

    def connect
      @started_at = Time.current

      Net::SSH.start(server.public_ip, Server::USER, key_data: [server.ssh_private_key], keys_only: true, non_interactive: true) do |session|
        @session = session
        yield(self)
      end

      @completed_at = Time.current
      remove_instance_variable(:@session)
      self
    end

    def execute(command)
      ssh_command = Command.new(command:, output: [], started_at: Time.current)
      @commands << ssh_command

      status = {}

      @session.exec!(command) do |_channel, stream, data|
        ssh_command.append_output(stream, data)
        yield(stream.to_s, data) if block_given?
      end

      ssh_command.completed_at = Time.current
      ssh_command.exit_code = status[:exit_code]
      ssh_command
    end
  end
end
