module Dokku
  module Domains
    DomainReport = Data.define(:domains_app_enabled, :domains_app_vhosts, :domains_global_enabled, :domains_global_vhosts)

    class ReportCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku domains:report #{@app}"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        data = text_output.lines.each_with_object({}) do |line, hash|
          next if line.blank?

          key, value = line.split(":", 2).map(&:strip)
          next if key.nil? || value.nil?

          key = key.downcase.tr(" ", "_")

          hash[key.to_sym] = if key.include?("_vhosts")
            value.split(" ")
          elsif value == "true"
            true
          elsif value == "false"
            false
          else
            value
          end
        end

        DomainReport.new(**data)
      end
    end
  end
end
