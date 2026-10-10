module Dokku
  module Git
    class AuthCommand
      def initialize(access_token:, host: "github.com")
        @access_token = access_token
        @host = host
      end

      def cmd
        "dokku git:auth #{@host} u #{@access_token}"
      end

      def redacted_cmd
        "dokku git:auth #{@host} u [FILTERED]"
      end
    end
  end
end
