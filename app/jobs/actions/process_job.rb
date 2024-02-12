module Actions
  class ProcessJob < ApplicationJob
    queue_as :default

    def perform(server_event)
      return unless server_event.status_pending?

      server_event.update_columns(job_id:)
      server_event.process
    end
  end
end
