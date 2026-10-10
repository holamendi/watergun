module Dokku
  module Storage
    class ListEntriesCommand
      def cmd
        "dokku storage:list-entries --scheduler docker-local --format json"
      end

      def parse_output(_exit_code, text_output)
        JSON.parse(text_output)
      end
    end
  end
end
