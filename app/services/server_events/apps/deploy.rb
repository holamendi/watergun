module ServerEvents
  module Apps
    class Deploy
      attr_reader :server_event

      def initialize(server_event)
        @server_event = server_event
      end

      def call
        server_event.update!(status: "running", running_at: Time.current)

        commands = []

        commands << "dokku git:auth github.com u #{app.org.git_credential.personal_access_token}" if app.org.git_credential.present?
        commands << "dokku git:sync --build #{app.dokku_name} http://github.com/#{app.git_repo}.git main"

        status, output = server_event.server.ssh_command!(commands.join(" && "))

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
