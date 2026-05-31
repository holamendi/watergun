module Dokku
  module Services
    class LinksCommand
      def initialize(plugin:, service:)
        @plugin = plugin
        @service = service
      end

      def cmd
        "dokku #{@plugin}:links #{@service}"
      end

      def parse_output(exit_code, text_output)
        return [] unless exit_code.zero?

        text_output.lines.map(&:strip).reject do |line|
          line.blank? ||
            line.start_with?("=====>") ||
            line.start_with?("----->") ||
            line.match?(/\Ano linked/i)
        end
      end
    end
  end
end
