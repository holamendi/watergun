module Dokku
  module Redis
    class Destroy
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def cmd
        "dokku redis:destroy #{service} --force"
      end
    end
  end
end
