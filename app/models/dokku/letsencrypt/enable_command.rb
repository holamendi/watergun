module Dokku
  module Letsencrypt
    class EnableCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku letsencrypt:enable #{app}"
      end
    end
  end
end
