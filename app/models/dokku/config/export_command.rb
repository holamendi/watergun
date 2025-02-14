module Dokku
  module Config
    class ExportCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku config:export #{@app} --format=json-list"
      end

      def parse_output(_exit_code, text_output)
        JSON.parse(text_output) || []
      end
    end
  end
end
