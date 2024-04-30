module Dokku
  module Git
    class Auth < Base
      attr_reader :host, :access_token

      def initialize(ssh_session, access_token:, host: "github.com")
        @ssh_session = ssh_session
        @access_token = access_token
        @host = host
      end

      def command
        "dokku git:auth #{host} u #{access_token}"
      end
    end
  end
end
