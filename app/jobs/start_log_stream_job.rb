class StartLogStreamJob < ApplicationJob
  include ActionView::RecordIdentifier

  def perform(log_stream)
    return if log_stream.streaming?

    log_stream.server.ssh_session do |ssh|
      log_stream.touch(:streaming_at)
      ssh.execute(log_command(log_stream), save_output: false) do |_stream, data|
        broadcast_log(log_stream, data)
      end
    end
  end

  private

  def broadcast_log(log_stream, data)
    Turbo::StreamsChannel.broadcast_append_to(
      log_stream,
      target: dom_id(log_stream),
      partial: "projects/apps/log_streams/log",
      locals: {log: data}
    )
  end

  def log_command(log_stream)
    streamable = log_stream.log_streamable
    command = case streamable
    when App
      "dokku logs #{streamable.dokku_id}"
    when Service
      "dokku #{streamable.service_type}:logs #{streamable.dokku_id}"
    end

    "#{command} -t LOG_STREAM_UUID=#{log_stream.uuid}"
  end
end
