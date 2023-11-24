module Dokku
  module Apps
    class Create
      def initialize(app)
        @app = app
      end

      def call
        status, output = app.server.ssh_command!("dokku apps:create #{app.name}")
      end
    end
  end
end
