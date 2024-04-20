module Dokku
  module Apps
    class Report < Base
      Parsed = Data.define(
        :created_at,
        :deploy_source,
        :deploy_source_metadata,
        :dir,
        :locked
      )

      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def call
        @command = ssh_session.execute("dokku apps:report #{app} --format json")
        json_report = JSON.parse(command.text_output)

        Parsed.new(
          created_at: Time.zone.at(json_report["app-created-at"].to_i),
          deploy_source: json_report["app-deploy-source"],
          deploy_source_metadata: json_report["app-deploy-source-metadata"],
          dir: json_report["app-dir"],
          locked: (json_report["app-locked"] == "true")
        )
      end
    end
  end
end
