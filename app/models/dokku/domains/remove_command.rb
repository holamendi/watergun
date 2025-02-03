module Dokku
  module Domains
    class RemoveCommand
      def initialize(app:, domain:)
        @app = app
        @domain = Array(domain)
      end

      def command
        "dokku domains:remove #{@app} #{@domain.join(" ")}"
      end
    end
  end
end
