module Dokku
  module Postgres
    class Link < Base
      attr_reader :app, :service

      def initialize(ssh_session, service:, app:)
        @ssh_session = ssh_session
        @service = service
        @app = app
      end

      def command
        "dokku postgres:link #{service} #{app}"
      end
    end
  end
end
