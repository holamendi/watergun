module Processors
  module Apps
    class Restart < Base
      def process
        execute("dokku ps:restart #{action.dokku_id}")
      end
    end
  end
end
