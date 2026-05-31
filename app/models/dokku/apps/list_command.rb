module Dokku
  module Apps
    class ListCommand
      def cmd
        "dokku apps:list"
      end

      def parse_output(exit_code, text_output)
        return [] unless exit_code.zero?

        text_output.lines.map(&:strip).reject do |line|
          line.blank? || line.start_with?("=====>") || line.start_with?("----->")
        end
      end
    end
  end
end
