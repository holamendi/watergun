module Dokku
  module Letsencrypt
    class Active < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku letsencrypt:active #{app}"
      end

      def parse
        result.text_output.strip == "true"
      end
    end
  end
end
