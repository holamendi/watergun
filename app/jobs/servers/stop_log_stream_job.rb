module Servers
  class StopLogStreamJob < ApplicationJob
    def perform(log_stream)
      session = log_stream.server.ssh_session do |ssh|
        ssh.execute("ps aux | grep 'LOG_STREAM_UUID=#{log_stream.uuid}' | grep -v grep | awk '{print $2}' | xargs sudo kill -9", save_output: false)
      end

      log_stream.destroy! if session.success?
    end
  end
end
