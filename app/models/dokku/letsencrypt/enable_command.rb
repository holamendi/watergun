module Dokku
  module Letsencrypt
    class EnableCommand
      def initialize(app:)
        @app = app
      end

      def command
        "dokku letsencrypt:enable #{app}"
      end
    end
  end
end
