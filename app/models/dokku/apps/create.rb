module Dokku
  module Apps
    class Create < Dokku::Command
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku apps:create #{app}"
      end
    end
  end
end
