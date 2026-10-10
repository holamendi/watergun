module Dokku
  module Storage
    class ListCommand
      def initialize(app:, phase: nil)
        raise ArgumentError, "Invalid storage phase" if phase && !%w[deploy run].include?(phase)
        @app = app
        @phase = phase
      end

      def cmd
        if @phase
          # plugin:trigger is root-only in Dokku 0.36.7. Watergun's installed
          # server user already has sudo; fail noninteractively if unavailable.
          Shellwords.join(["sudo", "-n", "dokku", "plugin:trigger", "storage-list", @app, @phase, "json"])
        else
          Shellwords.join(["dokku", "storage:list", @app, "--format", "json"])
        end
      end

      def parse_output(_exit_code, text_output)
        JSON.parse(text_output)
      end
    end
  end
end
