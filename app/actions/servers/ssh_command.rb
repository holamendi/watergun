module Servers
  class SshCommand
    Log = Data.define(:command, :output, :exit_code, :started_at, :completed_at) do
      def success? = logs.all? { _1.exit_code.zero? }

      def duration = completed_at - started_at
    end

    Result = Data.define(:logs, :started_at, :completed_at) do
      def success? = logs.all? { _1.exit_code.zero? }

      def duration = completed_at - started_at

      def output = logs.map(&:output).join
    end

    def initialize(server)
      @server = server
    end

    def call(commands)
      started_at = Time.current
      logs = []

      Net::SSH.start(@server.public_ip, Server::USER, key_data: [ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
        Array.wrap(commands).each_with_index do |command, index|
          next unless index.zero? || logs.last&.exit_code&.zero?

          output = ""
          status = {}
          started_at = Time.current

          ssh.exec!(command, status:) do |_channel, _stream, data|
            output << data
            yield(data) if block_given?
          end

          completed_at = Time.current

          logs << Log.new(
            command:,
            output:,
            exit_code: status[:exit_code],
            started_at:,
            completed_at:
          )
        end
      end

      completed_at = Time.current

      Result.new(logs:, started_at:, completed_at:)
    end

    private

    def ssh_private_key
      @server.dokku_user.ssh_private_key
    end
  end
end
