class Ssh::Command
  OutputEntry = Data.define(:timestamp, :stream, :data)

  attr_reader :command, :output, :started_at, :finished_at, :exit_code

  def initialize(command)
    @command = command
    @output = []
  end

  def start
    @started_at = Time.current
  end

  def command_str
    if @command.is_a?(String)
      @command
    elsif @command.respond_to?(:command)
      @command.command
    else
      raise "command must be a string or an object that responds to #command"
    end
  end

  def append_output(stream, data)
    @output << OutputEntry.new(timestamp: Time.current, stream: stream.to_s, data:)
  end

  def finish(exit_code)
    @finished_at = Time.current
    @exit_code = exit_code
  end

  def success?
    exit_code&.zero?
  end

  def failure?
    !success?
  end

  def finished?
    @finished_at.present?
  end

  def text_output
    @output.map(&:data).join
  end

  def json_output
    @output.map(&:to_h)
  end

  def parsed_output
    return unless finished?

    @parsed_output ||= if @command.is_a?(String)
      text_output
    elsif @command.respond_to?(:parse_output)
      @command.parse_output(exit_code, text_output)
    else
      raise "command must be a string or an object that responds to #parse_output"
    end
  end
end
