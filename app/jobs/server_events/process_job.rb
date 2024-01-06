module ServerEvents
  class ProcessJob < ApplicationJob
    queue_as :default

    def perform(server_event)
      return unless server_event.status_pending?

      server_event.update!(job_id:)
      server_event.process
    end
  end
end
