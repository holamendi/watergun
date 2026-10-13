module Dokku
  module Config
    class ExportCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku config:export #{@app} --format=json-list"
      end

      def sensitive_output?
        true
      end

      def parse_output(_exit_code, text_output)
        JSON.parse(text_output) || []
      rescue JSON::ParserError
        raise JSON::ParserError, "Invalid config export: [FILTERED]", cause: nil
      end
    end
  end
end
