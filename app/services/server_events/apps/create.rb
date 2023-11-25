module ServerEvents
  module Apps
    class Create
      attr_reader :server_event

      def initialize(server_event)
        @server_event = server_event
      end

      def call
        server_event.update!(status: "running", running_at: Time.current)

        status, output = server_event.server.ssh_command!("dokku apps:create #{app.dokku_name}")

        server_event.update!(status: status.zero? ? "success" : "failure", completed_at: Time.current)
        server_event.create_server_event_log!(content: output, org: server_event.org)

        if app.git_repo.present?
          app.server_events.create!(
            server:,
            org:,
            event_type: "apps.deploy",
            source: server_event.source
          )
        end
      end

      private

      def app
        server_event.eventable
      end

      def server
        server_event.server
      end

      def org
        server_event.org
      end
    end
  end
end
