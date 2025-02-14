module Dokku
  module Ps
    class RebuildCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku ps:rebuild #{@app}"
      end
    end
  end
end
