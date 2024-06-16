module Dokku
  module Domains
    class Report < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def domains_app_enabled
        parsed_output[:domains_app_enabled]
      end

      def domains_app_vhosts
        parsed_output[:domains_app_vhosts]
      end

      def domains_global_enabled
        parsed_output[:domains_global_enabled]
      end

      def domains_global_vhosts
        parsed_output[:domaisn_global_vhosts]
      end

      memoize def parsed_output
        return unless success?

        text_output.lines.each_with_object({}) do |line, hash|
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
      end

      private

      def command
        "dokku domains:report #{app}"
      end
    end
  end
end
