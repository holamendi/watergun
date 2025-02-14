module Dokku
  module Storage
    class EnsureDirectory
      attr_reader :directory

      def initialize(ssh_session, directory:, chown: nil)
        @ssh_session = ssh_session
        @directory = directory
      end

      def cmd
        cmd = "dokku storage:ensure_directory #{directory}"
        cmd += " --chown=#{chown}" if chown
        cmd
      end
    end
  end
end
