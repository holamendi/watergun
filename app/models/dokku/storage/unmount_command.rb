module Dokku
  module Storage
    class UnmountCommand
      attr_reader :app, :host_directory, :container_directory

      def initialize(app:, host_directory:, container_directory:)
        @app = app
        @host_directory = host_directory
        @container_directory = container_directory
      end

      def cmd
        "dokku storage:unmount #{app} #{host_directory}:#{container_directory}"
      end
    end
  end
end
