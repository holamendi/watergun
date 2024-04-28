module Dokku
  module Redis
    class Destroy < Base
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku redis:destroy #{service} --force"
      end
    end
  end
end
