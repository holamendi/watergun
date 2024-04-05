module Processors
  module Apps
    class Destroy < Base
      delegate :dokku_id, to: :action

      def process
        ssh.execute("dokku apps:destroy --force #{action.dokku_id}")
      end
    end
  end
end
