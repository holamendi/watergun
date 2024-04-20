module Dokku
  module Postgres
    class Link < Base
      attr_reader :app, :service

      def initialize(ssh_session, app:, service:)
        @ssh_session = ssh_session
        @app = app
        @service = service
        @command = nil
      end

      def call
        @command = ssh_session.execute("dokku postgres:link #{service} #{app}")
        self
      end
    end
  end
end
