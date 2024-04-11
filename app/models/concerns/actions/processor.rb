module Actions
  module Processor
    extend ActiveSupport::Concern

    included { attr_reader :ssh }

    def process
      raise "Action must implement #process_action" unless respond_to?(:process_action)

      Action.transaction do
        self.running_at = Time.current
        status_running!
        create_action_log!(org:)
        actionable.touch
      end

      result = server.ssh_session do |ssh|
        @ssh = ssh
        perform
      end

      self.completed_at = result.completed_at

      Action.transaction do
        result.success? ? status_success! : status_failure!
        action_log.update!(ssh_commands: result.commands)
        actionable.touch
      end
    rescue => e
      Action.transaction do
        self.completed_at = Time.current
        status_failure!
        actionable.touch
      end

      raise e if Rails.env.local?
    ensure
      @ssh = nil
    end
  end
end
