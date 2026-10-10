module Dokku
  module Storage
    class ListCommand
      def initialize(app:, phase: "deploy")
        raise ArgumentError, "Invalid storage phase" unless %w[deploy run].include?(phase)
        @app = app
        @phase = phase
      end

      def cmd
        Shellwords.join(["sudo", "-n", "dokku", "plugin:trigger", "storage-app-mounts", @app, @phase])
      end

      def parse_output(_exit_code, text_output)
        JSON.parse(text_output).map do |pair|
          entry = pair.fetch("entry")
          pair.fetch("attachment").merge("entry_name" => entry.fetch("name"), "host_path" => entry.fetch("host_path"), "scheduler" => entry.fetch("scheduler"))
        end
      end
    end
  end
end
