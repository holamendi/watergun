module Dokku
  module Apps
    class Destroy < Dokku::Command
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
        @command = nil
      end

      def command
        "dokku apps:destroy --force #{app}"
      end
    end
  end
end
