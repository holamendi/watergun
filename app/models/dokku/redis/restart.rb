module Dokku
  module Redis
    class Restart < Base
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku redis:restart #{service}"
      end
    end
  end
end
