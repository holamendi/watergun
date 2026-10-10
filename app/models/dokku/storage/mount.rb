module Dokku
  module Storage
    class Mount
      def initialize(app:, entry_name:, container_directory:)
        @app = app
        @entry_name = entry_name
        @container_directory = container_directory
      end

      def cmd
        Shellwords.join(["dokku", "storage:mount", @app, @entry_name, "--container-dir", @container_directory, "--phase", "deploy", "--phase", "run"])
      end
    end
  end
end
