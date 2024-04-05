module Processors
  module Apps
    class Create < Base
      delegate :dokku_id, to: :action

      def process
        ssh.execute("dokku apps:create #{action.dokku_id}")
      end
    end
  end
end
