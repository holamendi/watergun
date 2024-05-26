module ServerActionPerformable
  extend ActiveSupport::Concern

  class_methods do
    def perform_later!(actionable, depends_on: nil, **)
      action = create!(actionable:, preceding_action: depends_on, **)
      PerformServerActionJob.perform_later(action)
      action
    end

    def perform_action
      raise "server action must implement #perform" unless respond_to?(:perform, true)

      self.running_at = Time.current
      running!

      result = server.ssh_session do |ssh_session|
        with(ssh_session:) { perform }
      end

      create_log!(ssh_commands: result.commands)

      self.status = if result.success?
        :success
      else
        :failure
      end
    rescue ServerActionFailure => e
      self.status = :failure
      self.failure_message = e.message
    rescue => e
      self.status = :failure
      self.failure_message = e.detailed_message
      raise e if Rails.env.local?
    ensure
      self.finished_at = Time.current
      save!
    end
  end
end
