module Dokku
  module Storage
    class EnsureDirectory
      attr_reader :directory, :chown

      def initialize(directory:, chown: nil)
        @directory = directory
        @chown = chown
      end

      def cmd
        Shellwords.join(["dokku", "storage:ensure-directory", "--chown", chown.presence || "false", directory])
      end
    end
  end
end
