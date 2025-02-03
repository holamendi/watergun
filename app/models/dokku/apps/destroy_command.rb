module Dokku
  module Apps
    class DestroyCommand
      def initialize(app:)
        @app = app
      end

      def command
        "dokku apps:destroy --force #{@app}"
      end
    end
  end
end
