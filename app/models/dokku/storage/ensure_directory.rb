module Dokku
  module Storage
    class EnsureDirectory
      attr_reader :directory, :chown

      def initialize(directory:, chown: nil)
        @directory = directory
        @chown = chown
      end

      def cmd
        cmd = "dokku storage:ensure_directory #{directory}"
        cmd += " --chown=#{chown}" if chown
        cmd
      end
    end
  end
end
