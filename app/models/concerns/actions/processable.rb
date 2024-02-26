module Actions
  module Processable
    extend ActiveSupport::Concern

    included do
      attr_accessor :ssh_session
      alias_method :ssh, :ssh_session
    end

    def process
      transaction do
        self.running_at = Time.current
        status_running!
        create_action_log!(org:)
        actionable.touch
      end

      result = server.ssh_session do |session|
        self.ssh_session = session
        process_action
      end

      self.ssh_session = nil
      self.completed_at = result.completed_at

      transaction do
        result.success? ? status_success! : status_failure!
        action_log.update!(ssh_commands: result.commands)
        actionable.touch
      end
    rescue => e
      update!(
        status: "exception",
        completed_at: Time.current,
        exception: {
          message: e.message,
          backtrace: e.backtrace
        }
      )
    end

    def process_action(ssh)
      raise "Implement in subclass"
    end
  end
end
