module Dokku
  module Plugin
    class List < Base
      def initialize(ssh_session)
        @ssh_session = ssh_session
      end

      def command
        "dokku plugin:list"
      end

      memoize def parsed_output
        return unless success?

        text_output.split("\n").map(&:strip).map do |line|
          name, version, enabled = line.split(" ")
          {name:, version:, enabled: enabled == "enabled"}
        end
      end

      def installed?(name)
        parsed_output.any? { |plugin| plugin[:name] == name }
      end

      def enabled?(name)
        parsed_output.any? { |plugin| plugin[:name] == name && plugin[:enabled] }
      end
    end
  end
end
