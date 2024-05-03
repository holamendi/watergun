module Dokku
  module Redis
    class Info < Base
      attr_reader :service

      def initialize(ssh_session, service:)
        @ssh_session = ssh_session
        @service = service
      end

      def command
        "dokku redis:info #{service}"
      end

      def parse
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
