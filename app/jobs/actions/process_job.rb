module Actions
  class ProcessJob < ApplicationJob
    limits_concurrency to: 1, key: ->(action) { action.actionable }, duration: 30.minutes

    def perform(action)
      return unless action.status_pending?

      action.update_columns(job_id:)
      action.process
    end
  end
end
