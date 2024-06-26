module Servers
  class StopLogStreamJob < ApplicationJob
    def perform(app, log_stream_jid)
      app.server.ssh_session do |ssh|
        puts "Stopping log stream for #{log_stream_jid} app:#{app.dokku_id} jid:#{job_id}"
        ssh.execute("ps aux | grep 'STREAM_JID=#{log_stream_jid}' | grep -v grep | awk '{print $2}' | xargs sudo kill -9", save_output: false)
      end
    end
  end
end
