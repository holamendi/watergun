class SshCommand
  attr_reader :host, :user, :command, :key, :session

  def initialize(host:, command:, key:, user: "watergun", session: SecureRandom.uuid)
    @host = host
    @user = user
    @command = command
    @key = key
  end

  def execute
    Net::SSH.start(host, user, key_data: [key]) do |ssh|
      ssh.open_channel do |channel|
        channel.request_pty do |_, success|
          raise "Failed to open PTY" unless success

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
      end

      ssh.loop
    end
  end
end
