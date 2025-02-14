class Docker::StatsCommand
  def cmd
    "docker stats --format=json --no-stream"
  end

  def parse_output(exit_code, text_output)
    return unless exit_code.zero?

    text_output.lines.map { Docker::ContainerStats.new(it) }
  end
end
