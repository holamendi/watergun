module Dokku
  module Ps
    class Restart < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku ps:restart #{app}"
      end
    end
  end
end
