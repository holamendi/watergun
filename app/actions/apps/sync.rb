module Apps
  class Sync
    attr_reader :app

    def initialize(app:)
      @app = app
    end

    def call
      @urls = app.server.execute_ssh_commands("dokku urls #{app.dokku_name}").ssh_commands.first.output

      app.update!(urls: parse_urls(@urls))

      self
    end

    private

    def parse_urls(output)
      output.split("\n")
    end
  end
end
