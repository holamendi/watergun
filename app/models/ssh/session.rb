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

    Net::SSH.start(host, user, **connection_options) do |session|
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
    raise "session not connected" unless @session

    status = {}
    ssh_command = Ssh::Command.new(command)
    @commands << ssh_command
    ssh_command.start

    decoders = Hash.new { |hash, stream| hash[stream] = Ssh::TextDecoder.new }
    emit = lambda do |stream, data|
      next if data.empty?

      ssh_command.append_output(stream, data) if save_output
      yield(stream, ssh_command.sensitive_output? ? "[FILTERED]" : data) if block_given?
    end

    @session.exec!(ssh_command.cmd, status:) do |_channel, stream, data|
      emit.call(stream, decoders[stream].write(data))
    end
    decoders.each { |stream, decoder| emit.call(stream, decoder.finish) }

    ssh_command.finish(status[:exit_code])
    ssh_command
  end

  def execute!(command, save_output: true)
    ssh_command = execute(command, save_output:)

    if ssh_command.failure?
      @session.loop
      raise Ssh::CommandExecutionError.new(ssh_command)
    end

    ssh_command
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
end

class Ssh::CommandExecutionError < StandardError
  attr_reader :ssh_command

  def initialize(ssh_command)
    @ssh_command = ssh_command
  end

  def message
    "command failed with status #{ssh_command.exit_code}: #{ssh_command.redacted_cmd}"
  end
end
