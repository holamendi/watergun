module Dokku
  module Postgres
    class Destroy < Base
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @app_name = app_name
        @service = service
        @command = nil
      end

      def call
        @command = ssh_session.execute("dokku postgres:destroy #{service} --force")
        self
      end
    end
  end
end
