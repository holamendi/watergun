module Servers
  class LogStreamJob < ApplicationJob
    include ActionView::RecordIdentifier

    def perform(log_stream)
      app = log_stream.log_streamable

      log_stream.server.ssh_session do |ssh|
        ssh.execute("dokku logs #{app.dokku_id} -t LOG_STREAM_UUID=#{log_stream.uuid}", save_output: false) do |stream, data|
          Turbo::StreamsChannel.broadcast_append_to(
            log_stream,
            target: dom_id(log_stream),
            partial: "projects/apps/log_streams/log",
            locals: {log: data}
          )
        end
      end
    end
  end
end
