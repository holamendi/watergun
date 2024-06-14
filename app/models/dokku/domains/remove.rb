module Dokku
  module Domains
    class Remove < Base
      attr_reader :app, :domain

      def initialize(ssh_session, app:, domain:)
        @ssh_session = ssh_session
        @app = app
        @domain = Array.wrap(domain)
      end

      def command
        "dokku domains:remove #{app} #{domain.join(" ")}"
      end
    end
  end
end
