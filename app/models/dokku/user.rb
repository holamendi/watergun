class Dokku::User < ApplicationRecord
  belongs_to :org
  belongs_to :server

  attribute :private_key, default: -> { SSHKey.generate.private_key }

  validates :private_key, presence: true, uniqueness: true

  def ssh_private_key
    SSHKey.new(private_key)
  end

  def ssh_command(command)
    Net::SSH.start(server.public_ip, "watergun", key_data: [SSHKey.new(private_key).rsa_private_key], keys_only: true, non_interactive: true) do |ssh|
      ssh.open_channel do |channel|
        channel.exec(command) do |_, success|
          raise "Failed to execute command: #{command}" unless success

          channel.on_data do |_, data|
            # channel.send_data "\cC"

            puts data
          rescue
            # ActionCable.server.broadcast("stream_channel", {body: data})
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

      ssh.loop
    end
  end
end
