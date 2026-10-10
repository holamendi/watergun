module Dokku
  module Storage
    class UnmountCommand
      def initialize(app:, entry_name:, container_directory:)
        @app = app
        @entry_name = entry_name
        @container_directory = container_directory
      end

      def cmd
        Shellwords.join(["dokku", "storage:unmount", @app, @entry_name, "--container-dir", @container_directory])
      end
    end
  end
end
