module Dokku
  module Redis
    class Create < Dokku::Command
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku redis:create #{service}"
      end
    end
  end
end
