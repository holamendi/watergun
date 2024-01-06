module ServerEvents
  class Base
    attr_reader :server_event

    def initialize(server_event)
      @server_event = server_event
    end

    def call
      server_event.update!(status: "running", running_at: Time.current)
      server_event.create_server_event_log!(org:, content: "")

      result = execute_commands

      server_event.update!(
        status: result.success ? "success" : "failure",
        details: result.details,
        completed_at: Time.current
      )
    rescue => e
      server_event.update!(
        status: "exception",
        completed_at: Time.current,
        exception: {
          message: e.message,
          backtrace: e.backtrace
        }
      )
    end

    private

    def execute_commands
      result = []
      output = ""

      Net::SSH.start(server.public_ip, Server::USER, key_data: [server.dokku_user.ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
        Array.wrap(commands).each_with_index do |command, index|
          status = {}
          started_at = Time.current

          if index.zero? || result.present? && result.last[:exit_code].zero?
            ssh.exec!(command, status:) do |channel, stream, data|
              output << data
              server_event.server_event_log.update!(content: server_event.server_event_log.content + data.force_encoding("UTF-8"))
              Turbo::StreamsChannel.broadcast_append_to server_event.eventable, :server_events, target: "logs_server_event_#{server_event.id}", content: "<p>#{data}</p>"
            end

            finished_at = Time.current

            result << {
              command: command,
              exit_code: status[:exit_code],
              started_at: started_at,
              finished_at: finished_at
            }
          end
        end
      end

      OpenStruct.new(
        success: result.all? { |r| r[:exit_code].zero? },
        details: result,
        output: output
      )
    end

    def commands
      raise NotImplementedError
    end

    def app
      server_event.eventable if server_event.eventable_type == "App"
    end

    def server
      server_event.server
    end

    def org
      server_event.org
    end
  end
end
