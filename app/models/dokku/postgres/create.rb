module Dokku
  module Postgres
    class Create < Base
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
        @command = nil
      end

      def call
        @command = ssh_session.execute("dokku postgres:create #{service}")
        self
      end
    end
  end
end
