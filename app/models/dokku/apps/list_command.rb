module Dokku
  module Apps
    class ListCommand
      def cmd
        "dokku apps"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        text_output.lines[1..].map(&:strip)
      end
    end
  end
end
