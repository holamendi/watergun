module Dokku
  module Storage
    class Mount
      attr_reader :app, :host_directory, :container_directory

      def initialize(ssh_session, app:, host_directory:, container_directory: nil)
        @ssh_session = ssh_session
        @app = app
        @host_directory = host_directory
        @container_directory = container_directory
      end

      def cmd
        "dokku storage:mount #{app} #{host_directory}:#{container_directory}"
      end
    end
  end
end
