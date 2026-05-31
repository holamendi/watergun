module Dokku
  module Builder
    BuilderReport = Data.define(:selected, :computed_selected)

    class ReportCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku builder:report #{@app}"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        data = text_output.lines.each_with_object({}) do |line, hash|
          next if line.blank?

          key, value = line.split(":", 2).map(&:strip)
          next if key.nil? || value.nil?

          case key.downcase
          when "builder selected"
            hash[:selected] = value.presence
          when "builder computed selected"
            hash[:computed_selected] = value.presence
          end
        end

        BuilderReport.new(
          selected: data[:selected],
          computed_selected: data[:computed_selected]
        )
      end
    end
  end
end
