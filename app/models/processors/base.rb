module Processors
  class Base
    attr_reader :action, :ssh

    delegate :actionable, :org, :server, to: :action
    delegate :execute, to: :ssh

    def initialize(action)
      @action = action
    end

    def call
      Action.transaction do
        action.running_at = Time.current
        action.status_running!
        action.create_action_log!(org:)
        actionable.touch
      end

      result = server.ssh_session do |ssh|
        @ssh = ssh
        process
        @ssh = nil
      end

      action.completed_at = result.completed_at

      Action.transaction do
        result.success? ? action.status_success! : action.status_failure!
        action.action_log.update!(ssh_commands: result.commands)
        actionable.touch
      end
    rescue => e
      raise e if Rails.env.development?
      action.update!(
        status: "exception",
        completed_at: Time.current,
        exception: {
          message: e.message,
          backtrace: e.backtrace
        }
      )
      actionable.touch
    end
  end
end
