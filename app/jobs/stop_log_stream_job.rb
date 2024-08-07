class StopLogStreamJob < ApplicationJob
  def perform(server, log_stream_uuid)
    server.ssh_session do |ssh|
      ssh.execute(kill_log_stream_command(log_stream_uuid))
    end
  end

  private

  def kill_log_stream_command(log_stream_uuid)
    "pgrep -f 'LOG_STREAM_UUID=#{log_stream_uuid}' | xargs sudo kill -9"
  end
end
