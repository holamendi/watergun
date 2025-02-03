module Dokku
  module Git
    class AuthCommand
      def initialize(access_token:, host: "github.com")
        @access_token = access_token
        @host = host
      end

      def command
        "dokku git:auth #{@host} u #{@access_token}"
      end
    end
  end
end
