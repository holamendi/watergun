module Dokku
  module Storage
    class List
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku storage:list #{app} --format json"
      end

      memoize def parsed_output
        JSON.parse(text_output)
      end
    end
  end
end
