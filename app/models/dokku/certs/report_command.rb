module Dokku
  module Certs
    CertReport = Data.define(:ssl_enabled)

    class ReportCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku certs:report #{@app}"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        ssl_enabled = text_output.lines.find do |line|
          line.strip.downcase.start_with?("ssl enabled:")
        end

        CertReport.new(ssl_enabled: ssl_enabled&.split(":", 2)&.last&.strip == "true")
      end
    end
  end
end
