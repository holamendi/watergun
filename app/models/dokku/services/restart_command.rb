module Dokku
  module Services
    class RestartCommand
      def initialize(plugin:, service:)
        @plugin = plugin
        @service = service
      end

      def command
        "dokku #{@plugin}:restart #{@service}"
      end
    end
  end
end
