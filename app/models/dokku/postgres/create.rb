module Dokku
  module Postgres
    class Create < Dokku::Command
      VERSIONS = %w[
        16.2
      ]

      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku postgres:create #{service}"
      end
    end
  end
end
