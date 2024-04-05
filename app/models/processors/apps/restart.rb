module Processors
  module Apps
    class Restart < Base
      delegate :dokku_id, to: :action

      def process
        ssh.execute("dokku ps:restart #{action.dokku_id}")
      end
    end
  end
end
