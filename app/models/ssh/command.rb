class Ssh::Command
  attr_reader :input, :output, :started_at, :finished_at, :exit_code

  def initialize(input)
    @input = input
    @output = []
  end

  def start
    @started_at = Time.current
  end

  def cmd
    @cmd ||= if @input.is_a?(String)
      @input
    elsif @input.respond_to?(:cmd)
      @input.cmd
    else
      raise "input must be a string or an object that responds to #cmd"
    end
  end

  def append_output(stream, data)
    @output << Ssh::Log.new(timestamp: Time.current, stream: stream.to_s, data:)
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

  def as_json(_options = {})
    {
      cmd:,
      exit_code:,
      started_at:,
      finished_at:,
      output:
    }
  end

  def parsed_output
    return unless finished?

    @parsed_output ||= if @input.is_a?(String)
      text_output
    elsif @input.respond_to?(:parse_output)
      @input.parse_output(exit_code, text_output)
    else
      raise "input must be a string or an object that responds to #parse_output"
    end
  end
end
