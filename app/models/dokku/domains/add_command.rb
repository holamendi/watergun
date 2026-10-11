module Dokku
  module Domains
    class AddCommand
      def initialize(app:, domain:)
        @app = app
        @domain = Array.wrap(domain)
      end

      def cmd
        Shellwords.join(["dokku", "domains:add", @app, *@domain])
      end
    end
  end
end
