module Docker
  class Stats < Docker::Command
    def initialize(ssh_session)
      @ssh_session = ssh_session
    end

    def command
      "docker stats --no-stream --format=json"
    end

    memoize def stats
      return unless success?

      result.text_output.lines.map { |line| Docker::ContainerStats.new(line) }
    end
  end
end
