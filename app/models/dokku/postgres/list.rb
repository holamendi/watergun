module Dokku
  module Postgres
    class List < Dokku::Command
      def initialize(ssh_session)
        @ssh_session = ssh_session
      end

      def command
        "dokku postgres:list"
      end

      def parsed_output
        nil unless success?

        result.text_output.lines[1..].map do |line|
          line.strip
        end
      end
    end
  end
end
