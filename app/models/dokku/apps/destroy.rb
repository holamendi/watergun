module Dokku
  module Apps
    class Destroy < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
        @command = nil
      end

      def call
        @command = ssh_session.execute("dokku apps:destroy --force #{app}")
      end

      def success?
        command.success?
      end
    end
  end
end
