module Dokku
  class CommandJob < ApplicationJob
    queue_as :default

    def perform(server:, command:, eventable:, membership: nil)
      event = Dokku::Event.create!(
        org: server.org,
        server:,
        eventable:,
        command: "dokku #{command}",
        status: "running",
        job_id: job_id
      )
      log = server.ssh_command!(command)
      event.update!(status: "success", completed_at: Time.current)
      event.create_dokku_log!(content: log, org: server.org)
    end
  end
end
