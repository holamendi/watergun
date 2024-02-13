module Actions
  class ProcessJob < ApplicationJob
    queue_as :default

    def perform(action)
      return unless action.status_enqueued?

      action.update_columns(job_id:)
      action.process
    end
  end
end
