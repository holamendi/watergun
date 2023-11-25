module ServerEvents
  module Apps
    class Deploy
      attr_reader :server_event

      def initialize(server_event)
        @server_event = server_event
      end

      def call
        server_event.update!(status: "running", running_at: Time.current)

        status, output = server_event.server.ssh_command!("dokku git:sync --build #{app.dokku_name} http://github.com/#{app.git_repo}.git main")

        server_event.update!(status: status.zero? ? "success" : "failure", completed_at: Time.current)
        server_event.create_server_event_log!(content: output, org: server_event.org)
      end

      private

      def app
        server_event.eventable
      end
    end
  end
end
