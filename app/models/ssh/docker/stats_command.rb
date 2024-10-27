class Ssh::Docker::StatsCommand
  def command = "docker stats --format=json --no-stream"

  def parse_output(exit_code, output)
    return unless exit_code.zero?

    output.lines.map { Ssh::Docker::ContainerStats.new(_1) }
  end
end
