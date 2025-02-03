module Dokku
  module Config
    class ExportCommand
      def initialize(app:)
        @app = app
      end

      def command
        "dokku config:export #{@app} --format=json-list"
      end

      def parse_output(exit_code, text_output)
        return {} unless exit_code.zero?

        JSON.parse(text_output)
      end
    end
  end
end
