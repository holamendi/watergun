module ServerEvents
  module Apps
    class Create
      attr_reader :server_event

      def initialize(server_event)
        @server_event = server_event
      end

      def call
        server_event.update!(status: "running", running_at: Time.current)

        commands = [
          "dokku apps:create #{app.dokku_name}",
          "dokku builder:set #{app.dokku_name} selected #{app.dokku_builder}"
        ]

        status, output = server_event.server.ssh_command!(commands.join(" && "), server_event)

        server_event.create_server_event_log!(content: output, org: server_event.org)
        server_event.update!(status: status.zero? ? "success" : "failure", completed_at: Time.current)

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
