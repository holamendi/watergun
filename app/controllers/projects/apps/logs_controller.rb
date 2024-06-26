module Projects
  module Apps
    class LogsController < BaseController
      def index
      end

      def fetch
        logs = current_server.ssh_session do |ssh|
          ssh.execute("dokku logs -n 1000 #{current_app.dokku_id}")
        end

        @output = logs.text_output
      end
    end
  end
end
