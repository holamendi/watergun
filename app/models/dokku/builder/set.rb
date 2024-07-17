module Dokku
  module Builder
    class Set < Dokku::Command
      attr_reader :app, :builder

      def initialize(ssh_session, app:, builder:)
        @ssh_session = ssh_session
        @app = app
        @builder = builder
      end

      def command
        "dokku builder:set #{app} selected #{builder}"
      end
    end
  end
end
