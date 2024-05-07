module Dokku
  module Letsencrypt
    class Enable < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku letsencrypt:enable #{app}"
      end
    end
  end
end
