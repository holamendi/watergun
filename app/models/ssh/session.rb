class Ssh::Session
  attr_reader :host, :user, :private_key, :port, :commands, :started_at, :finished_at

  def initialize(host:, user:, private_key:, port: 22)
    @host = host
    @user = user
    @private_key = private_key
    @port = port
    @commands = []
  end

  def connect
    @started_at = Time.current

    Net::SSH.start(host, user, connection_options) do |session|
      @session = session
      yield(self)
      @session.loop
    end

    self
  ensure
    @finished_at = Time.current
    @session = nil
  end

  def execute(command, save_output: true)
    ssh_command = Ssh::Command.new(command)
    @commands << ssh_command
    ssh_command.start

    status = {}
    execute_command(ssh_command, status, save_output:) do |stream, data|
      yield(stream.to_s, data) if block_given?
    end

    ssh_command.finish(status[:exit_code])
    ssh_command
  end

  def execute!(command, save_output: true)
    result = execute(command, save_output:)
    raise Ssh::CommandExecutionError.new(command, result) if result.failure?

    result
  end

  def success?
    commands.all?(&:success?)
  end

  def status
    success? ? :success : :failure
  end

  def text_output
    @text_output ||= commands.map(&:text_output).join("\n")
  end

  private

  def connection_options
    {
      port:,
      key_data: [private_key],
      keys_only: true,
      non_interactive: true
    }
  end

  def execute_command(ssh_command, status, save_output: true)
    @session.exec!(ssh_command.command_str, status:) do |_channel, stream, data|
      ssh_command.append_output(stream, data) if save_output
      yield(stream, data) if block_given?
      Rails.logger.debug(data&.strip) if Rails.env.development?
    end
  end
end

class Ssh::CommandExecutionError < StandardError
  attr_reader :command, :result

  def initialize(command, result)
    @command = command
    @result = result
  end

  def message
    "command failed with status #{result.exit_code}: #{command}"
  end
end
