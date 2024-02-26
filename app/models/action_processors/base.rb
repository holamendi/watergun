module ActionProcessors
  class Base
    attr_reader :action, :ssh_session

    delegate :actionable, :org, :server, to: :action

    def initialize(action)
      @action = action
    end

    def execute
      Action.transaction do
        action.running_at = Time.current
        action.status_running!
        action.create_action_log!(org:)
        actionable.touch
      end

      result = server.ssh_session do |session|
        @ssh_session = session
        process
      end

      @ssh_session = nil

      action.completed_at = result.completed_at

      Action.transaction do
        if result.success?
          action.status_success!
        else
          action.status_failure!
        end
        action.action_log.update!(ssh_commands: result.commands)
        actionable.touch
      end
    rescue => e
      action.update!(
        status: "exception",
        completed_at: Time.current,
        exception: {
          message: e.message,
          backtrace: e.backtrace
        }
      )
    end
  end
end
