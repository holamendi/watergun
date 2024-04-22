module Dokku
  module Postgres
    class Unlink < Base
      attr_reader :app, :service

      def initialize(ssh_session, app:, service:)
        @ssh_session = ssh_session
        @app = app
        @service = service
      end

      def command
        "dokku postgres:unlink #{service} #{app}"
      end

      def call
        ssh_session.execute(command)
        self
      end
    end
  end
end
