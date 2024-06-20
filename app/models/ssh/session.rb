module Ssh
  class Session
    attr_reader :server, :commands, :started_at, :finished_at

    def initialize(server:)
      @server = server
      @commands = []
    end

    def connect
      @started_at = Time.current

      Net::SSH.start(server.public_ip, SshKey::USER, key_data: [ssh_private_key], keys_only: true, non_interactive: true) do |session|
        @session = session
        yield(self)
      end
      @finished_at = Time.current
      @session = nil
      self
    end

    def execute(command)
      ssh_command = Ssh::Command.new(command:, started_at: Time.current)
      @commands << ssh_command

      status = {}

      @session.exec!(command, status:) do |_channel, stream, data|
        ssh_command.append_output(stream, data)
        yield(stream.to_s, data) if block_given?

        Rails.logger.debug(data&.strip) if Rails.env.development?
      end

      ssh_command.finished_at = Time.current
      ssh_command.exit_code = status[:exit_code]
      ssh_command
    end

    def execute!(command)
      result = execute(command)
      raise CommandExecutionError.new(command, result) if result.failure?
      result
    end

    def success?
      commands.all?(&:success?)
    end

    def status
      success? ? :success : :failure
    end

    def text_output
      commands.map(&:output).join("\n")
    end

    private

    def ssh_private_key
      server.ssh_key.private_key
    end
  end

  class CommandExecutionError < StandardError
    attr_reader :command, :result

    def initialize(command, result)
      @command = command
      @result = result
    end

    def message
      "command failed with status #{result.exit_code}: #{command}"
    end
  end
end
