module Dokku
  module Plugin
    PluginData = Data.define(:name, :version, :enabled)

    class ListCommand
      def cmd
        "dokku plugin:list"
      end

      def parse_output(exit_code, text_output)
        return unless exit_code.zero?

        text_output.split("\n").map(&:strip).map do |line|
          name, version, enabled = line.split(" ")
          PluginData.new(name:, version:, enabled: (enabled == "enabled"))
        end
      end
    end
  end
end
