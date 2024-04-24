module Dokku
  module Ps
    class Rebuild < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku ps:rebuild #{app}"
      end
    end
  end
end
