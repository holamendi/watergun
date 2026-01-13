module Dokku
  module Ps
    class RestartCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku ps:restart #{@app}"
      end
    end
  end
end
