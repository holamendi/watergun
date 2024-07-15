module Dokku
  module Mongo
    class Link < Dokku::Command
      attr_reader :app, :service, :restart

      def initialize(ssh_session, service:, app:, restart: false)
        @ssh_session = ssh_session
        @service = service
        @app = app
      end

      def command
        cmd = "dokku mongo:link #{service} #{app}"
        cmd += " --no-restart" unless restart
        cmd
      end
    end
  end
end
