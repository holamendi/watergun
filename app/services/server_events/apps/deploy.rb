module ServerEvents
  module Apps
    class Deploy
      attr_reader :server_event

      def initialize(server_event)
        @server_event = server_event
      end

      def call
        server_event.update!(status: "running", running_at: Time.current)

        commands = [
          "dokku git:auth github.com u #{app.org.git_credential.personal_access_token}",
          "dokku git:sync --build #{app.dokku_name} http://github.com/#{app.git_repo}.git #{app.git_branch}"
        ]

        status, output = server_event.server.ssh_command!(commands.join(" && "), server_event)

        server_event.create_server_event_log!(content: output, org: server_event.org)
        server_event.update!(status: status.zero? ? "success" : "failure", completed_at: Time.current)
      end

      private

      def app
        server_event.eventable
      end
    end
  end
end
