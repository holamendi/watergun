module Dokku
  module Domains
    class AddCommand
      def initialize(app:, domain:)
        @app = app
        @domain = Array.wrap(domain)
      end

      def cmd
        "dokku domains:add #{@app} #{@domain.join(" ")}"
      end
    end
  end
end
