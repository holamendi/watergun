module ServerEvents
  class Base
    attr_reader :server_event

    delegate :eventable, :org, :server, to: :server_event

    def initialize(server_event)
      @server_event = server_event
    end

    def call
      ServerEvent.transaction do
        server_event.update!(status: "running", running_at: Time.current)
        server_event.create_server_event_log!(org:)
      end

      result = execute_ssh_commands
      ::Apps::Sync.new(app: eventable).call if eventable.is_a?(App)

      ServerEvent.transaction do
        server_event.update!(status: result.success? ? "success" : "failure", completed_at: result.completed_at)
        server_event.server_event_log.update!(ssh_commands: result.ssh_commands)
      end
      # rescue => e
      # server_event.update!(
      #   status: "exception",
      #   completed_at: Time.current,
      #   exception: {
      #     message: e.message,
      #     backtrace: e.backtrace
      #   }
      # )
    end

    private

    def commands
      raise NotImplementedError
    end

    def after_execute
      nil
    end

    def execute_ssh_commands
      server.execute_ssh_commands(commands) do |data|
        Turbo::StreamsChannel.broadcast_append_to server_event.eventable, :server_events, target: "logs_server_event_#{server_event.id}", content: "<p>#{data}</p>"
      end
    end
  end
end
