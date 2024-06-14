module Dokku
  module Domains
    class Report < Base
      attr_reader :app

      def initialize(ssh_session, app:)
        @ssh_session = ssh_session
        @app = app
      end

      def command
        "dokku domains:report #{app}"
      end

      def parsed_output
        return unless success?

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
