module Dokku
  module Apps
    class Report < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku apps:report #{app} --format json"
      end

      def parsed_output
        return unless success?

        JSON.parse(result.text_output).then do |json|
          {
            created_at: Time.zone.at(json["app-created-at"].to_i),
            deploy_source: json["app-deploy-source"],
            deploy_source_metadata: json["app-deploy-source-metadata"],
            dir: json["app-dir"],
            locked: (json["app-locked"] == "true")
          }
        end
      end
    end
  end
end
