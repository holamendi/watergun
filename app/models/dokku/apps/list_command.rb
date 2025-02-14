module Dokku
  module Apps
    class ListCommand
      def cmd
        "dokku apps"
      end

      def parse_output(_exit_code, text_output)
        text_output.lines[1..].map(&:strip)
      end
    end
  end
end
