module Dokku
  module Storage
    class Mount
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
          Shellwords.join(["dokku", "docker-options:add", app, @phase, "-v #{host_directory}:#{container_directory}"])
        else
          Shellwords.join(["dokku", "storage:mount", app, "#{host_directory}:#{container_directory}"])
        end
      end
    end
  end
end
