module Dokku
  module Mongo
    class Create < Dokku::Command
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku mongo:create #{service}"
      end
    end
  end
end
