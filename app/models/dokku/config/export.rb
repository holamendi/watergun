module Dokku
  module Config
    class Export < Dokku::Command
      attr_reader :app, :env, :restart

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku config:export #{app} --format=json-list"
      end

      memoize def parsed_output
        return unless success?

        JSON.parse(text_output)
      end
    end
  end
end
