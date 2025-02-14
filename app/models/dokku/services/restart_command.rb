module Dokku
  module Services
    class RestartCommand
      def initialize(plugin:, service:)
        @plugin = plugin
        @service = service
      end

      def cmd
        "dokku #{@plugin}:restart #{@service}"
      end
    end
  end
end
