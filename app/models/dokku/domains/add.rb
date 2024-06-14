module Dokku
  module Domains
    class Add < Base
      attr_reader :app, :domain

      def initialize(ssh_session, app:, domain:)
        @ssh_session = ssh_session
        @app = app
        @domain = Array.wrap(domain)
      end

      def command
        "dokku domains:add #{app} #{domain.join(" ")}"
      end
    end
  end
end
