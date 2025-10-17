class StartLogStreamJob < ApplicationJob
  include ActionView::RecordIdentifier

  def perform(log_stream)
    return if log_stream.streaming?

    log_stream.server.ssh_session do |ssh|
      log_stream.touch(:streaming_at)

      buffer = Ssh::StreamBuffer.new(interval: 0.1)
      buffer.start { |logs| broadcast_log(log_stream, logs) }

      ssh.execute(log_command(log_stream), save_output: false) do |stream, data|
        buffer.write(Ssh::Log.new(stream:, data:))
      end
    ensure
      buffer&.stop { |logs| broadcast_log(log_stream, logs) }
    end
  end

  private

  def broadcast_log(log_stream, logs)
    Turbo::StreamsChannel.broadcast_append_to(
      log_stream,
      target: dom_id(log_stream),
      partial: "shared/log_streams/log",
      locals: {logs:}
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
