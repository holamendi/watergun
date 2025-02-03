module Dokku
  module Builder
    class SetCommand
      def initialize(app:, builder:)
        @app = app
        @builder = builder
      end

      def command
        "dokku builder:set #{@app} selected #{@builder}"
      end
    end
  end
end
