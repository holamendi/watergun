module Dokku
  module Postgres
    class Restart < Base
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku postgres:restart #{service}"
      end

      def call
        ssh_session.execute(command)
        self
      end
    end
  end
end
