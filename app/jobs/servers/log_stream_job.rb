module Servers
  class LogStreamJob < ApplicationJob
    def perform(app)
      return
      return unless app.deployed?

      app.server.ssh_session do |ssh|
        puts "Starting log stream app:#{app.dokku_id} jid:#{job_id}"
        ssh.execute("dokku logs #{app.dokku_id} -t STREAM_JID=#{job_id}", save_output: false) do |stream, data|
          ActionCable.server.broadcast("log_stream_#{job_id}", {body: data})
        end
      end
    end
  end
end
