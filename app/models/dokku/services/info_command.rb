module Dokku
  module Services
    class InfoCommand
      def initialize(plugin:, service:)
        @plugin = plugin
        @service = service
      end

      def command
        "dokku #{@plugin}:info #{@service}"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        text_output.lines.each_with_object({}) do |line, hash|
          next if line.blank?

          key, value = line.split(":", 2).map(&:strip)
          next if key.nil? || value.nil?

          hash[key.downcase.tr(" ", "_").to_sym] = value
        end
      end
    end
  end
end
