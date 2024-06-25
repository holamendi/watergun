class StreamAppLogsJob < ApplicationJob
  def perform(app)
    return unless app.deployed?

    puts "****** #{job_id}"

    server = app.server
    ssh_private_key = server.ssh_key.private_key

    Net::SSH.start(server.public_ip, SshKey::USER, key_data: [ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
      channel = ssh.open_channel do |ch|
        ch.request_pty do |_, success|
          raise "Failed to open PTY" unless success

          ch.exec("dokku logs #{app.dokku_id} -t") do |_, success|
            puts "SDAOIPSJDOAISD(((@(#@#@#))))"

            raise "Failed to execute command: dokku logs" unless success

            ch.on_data do |_, data|
              puts "ASDASDASDASDSD"

              ActionCable.server.broadcast("stream_#{job_id}", {body: data})
            end

            ch.on_extended_data do |_, _, data|
              puts "Error: #{data}"
            end

            ch.on_close do
              puts "Channel closed"
            end
          end
        end
      end
    end
  end
end
