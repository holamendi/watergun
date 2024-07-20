class StopLogStreamJob < ApplicationJob
  def perform(log_stream)
    log_stream.server.ssh_session do |ssh|
      ssh.execute(kill_log_stream_command(log_stream), save_output: false)
    end

    log_stream.destroy!
  end

  private

  def kill_log_stream_command(log_stream)
    "pgrep -f 'LOG_STREAM_UUID=#{log_stream.uuid}' | xargs sudo kill -9"
  end
end
