module Dokku
  module Services
    class CreateCommand
      def initialize(plugin:, name:)
        @plugin = plugin
        @name = name
      end

      def command
        "dokku #{@plugin}:create #{@name}"
      end
    end
  end
end
