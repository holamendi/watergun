module Dokku
  class AppLogStreamJob < ApplicationJob
    queue_as :default

    def perform(*args)
      Rails.cache.write("stream_#{job_id}", true)

      Net::SSH.start("watergun") do |ssh|
        ssh.open_channel do |channel|
          channel.request_pty do |_, success|
            raise "Failed to open PTY" unless success

            channel.exec(command) do |_, success|
              raise "Failed to execute command: #{command}" unless success

              channel.on_data do |_, data|
                if Rails.cache.read("stream_#{job_id}").nil?
                  channel.send_data "\cC"
                end

                ActionCable.server.broadcast("stream_channel", {body: data})
              end

              channel.on_extended_data do |_, type, data|
                # This block will capture error messages, if any
                puts "Error: #{data}" if type == 1
              end

              # You can send input to the remote command if needed
              # channel.send_data("input_data_here")

              channel.on_close do
                puts "Channel closed"
              end
            end
          end
        end

        ssh.loop

        # Wait for all channels to close
      end
    end
  end
end
