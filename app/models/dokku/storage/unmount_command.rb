module Dokku
  module Storage
    class UnmountCommand
      attr_reader :app, :host_directory, :container_directory

      def initialize(app:, host_directory:, container_directory:, phase: nil)
        raise ArgumentError, "Invalid storage phase" if phase && !%w[deploy run].include?(phase)
        @phase = phase
        @app = app
        @host_directory = host_directory
        @container_directory = container_directory
      end

      def cmd
        if @phase
          # Dokku removes options using a # delimited sed basic regex.
          # Quote regex metacharacters separately from the shell token.
          option = "-v #{host_directory}:#{container_directory}".gsub(/[\\.\[\]*^$#]/) { |character| "\\#{character}" }
          Shellwords.join(["dokku", "docker-options:remove", app, @phase, option])
        else
          Shellwords.join(["dokku", "storage:unmount", app, "#{host_directory}:#{container_directory}"])
        end
      end
    end
  end
end
