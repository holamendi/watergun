module Actions
  class Base
    attr_reader :action

    delegate :actionable, :org, :server, to: :action

    def initialize(action)
      @action = action
    end

    def call
      Action.transaction do
        action.update!(status: :running, running_at: Time.current)
        action.create_action_log!(org:)
      end

      result = server.execute_ssh_commands(commands)

      Action.transaction do
        action.update!(status: result.success? ? :success : :failure, completed_at: result.completed_at)
        action.action_log.update!(ssh_commands: result.ssh_commands)
      end
      # rescue => e
      #   action.update!(
      #     status: "exception",
      #     completed_at: Time.current,
      #     exception: {
      #       message: e.message,
      #       backtrace: e.backtrace
      #     }
      #   )
    end

    private

    def commands
      raise "Implement in subclass"
    end
  end
end
