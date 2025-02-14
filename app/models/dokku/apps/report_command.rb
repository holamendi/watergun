module Dokku
  module Apps
    AppReport = Data.define(:created_at, :deploy_source, :deploy_source_metadata, :dir, :locked)

    class ReportCommand
      def initialize(app:)
        @app = app
      end

      def cmd
        "dokku apps:report #{@app} --format json"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        json = JSON.parse(text_output)

        AppReport.new(
          created_at: Time.zone.at(json["app-created-at"].to_i),
          deploy_source: json["app-deploy-source"],
          deploy_source_metadata: json["app-deploy-source-metadata"],
          dir: json["app-dir"],
          locked: (json["app-locked"] == "true")
        )
      end
    end
  end
end
