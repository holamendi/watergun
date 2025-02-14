module Dokku
  module Apps
    class CreateCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku apps:create #{@app}"
      end
    end
  end
end
