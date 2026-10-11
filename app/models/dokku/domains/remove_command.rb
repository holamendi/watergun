module Dokku
  module Domains
    class RemoveCommand
      def initialize(app:, domain:)
        @app = app
        @domain = Array(domain)
      end

      def cmd
        Shellwords.join(["dokku", "domains:remove", @app, *@domain])
      end
    end
  end
end
