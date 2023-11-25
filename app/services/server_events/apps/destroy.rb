module ServerEvents
  module Apps
    class Destroy
      attr_reader :server_event

      def initialize(server_event)
        @server_event = server_event
      end

      def call
        server_event.update!(status: "running", running_at: Time.current)

        status, output = server_event.server.ssh_command!("dokku apps:destroy --force #{dokku_app}")

        server_event.update!(status: status.zero? ? "success" : "failure", completed_at: Time.current)
        server_event.create_server_event_log!(content: output, org: server_event.org)
      end

      private

      def dokku_app
        server_event.args["dokku_app"]
      end
    end
  end
end
