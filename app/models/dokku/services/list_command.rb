module Dokku
  module Services
    class ListCommand
      def initialize(plugin:)
        @plugin = plugin
      end

      def command
        "dokku #{@plugin}:list"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        text_output.lines[1..].map do |line|
          line.strip
        end
      end
    end
  end
end
