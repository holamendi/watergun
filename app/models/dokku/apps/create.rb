module Dokku
  module Apps
    class Create < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
        @command = nil
      end

      def call
        @command = ssh_session.execute("dokku apps:create #{app}")
        self
      end
    end
  end
end
