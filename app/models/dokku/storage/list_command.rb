module Dokku
  module Storage
    class ListCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku storage:list #{@app} --format json"
      end

      def parse_output(_exit_code, text_output)
        JSON.parse(text_output)
      end
    end
  end
end
