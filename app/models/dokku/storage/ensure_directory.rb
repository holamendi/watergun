module Dokku
  module Storage
    class EnsureDirectory < Base
      attr_reader :directory

      def initialize(ssh_session, directory:, chown: nil)
        @ssh_session = ssh_session
        @directory = directory
      end

      def command
        cmd = "dokku storage:ensure_directory #{directory}"
        cmd += " --chown=#{chown}" if chown
        cmd
      end
    end
  end
end
