module Dokku
  module Redis
    class Restart
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def cmd
        "dokku redis:restart #{service}"
      end
    end
  end
end
