module ActionProcessors
  class Base
    attr_reader :action, :ssh

    delegate :actionable, :org, :server, to: :action

    def initialize(action)
      @action = action
      @ssh = nil
    end

    def call
      Action.transaction do
        action.running_at = Time.current
        action.status_running!
        action.create_action_log!(org:)
      end

      result = server.ssh_connection do |ssh|
        @ssh = ssh
        process
      end

      @ssh = nil

      action.completed_at = result.completed_at
      if result.success?
        action.status_success!
        actionable.enqueue_next_action!(action)
      else
        action.status_failure!
      end
      action.action_log.update!(ssh_commands: result.ssh_commands)
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

    def process
      raise "Implement in subclass"
    end
  end
end
