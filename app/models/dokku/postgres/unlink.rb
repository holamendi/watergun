module Dokku
  module Postgres
    class Unlink < Base
      attr_reader :app, :service

      def initialize(ssh_session, app:, service:)
        @ssh_session = ssh_session
        @app = app
        @service = service
        @command = nil
      end

      def call
        @command = ssh_session.execute("dokku service:unlink #{service} #{app}")
        self
      end
    end
  end
end
