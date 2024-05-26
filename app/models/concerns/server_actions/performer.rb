module ServerActions
  module Performer
    extend ActiveSupport::Concern

    included do
      attr_accessor :ssh_session
      alias_method :ssh, :ssh_session
    end

    class_methods do
      def perform_later!(actionable, depends_on: nil, **)
        action = create!(actionable:, preceding_action: depends_on, **)
        PerformServerActionJob.perform_later(action)
        action
      end
    end

    def perform_action
      raise "server action must implement #perform" unless respond_to?(:perform, true)

      self.running_at = Time.current
      running!

      result = server.ssh_session do |ssh_session|
        with(ssh_session:) { perform }
      end

      create_log!(ssh_commands: result.commands)

      self.status = result.status
    rescue => e
      self.status = :failure
      self.failure_message = e.detailed_message
    ensure
      self.finished_at = Time.current
      save!
    end
  end
end
