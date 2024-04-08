module Processors
  module Apps
    class Create < Base
      delegate :app_dokku_id, to: :action

      def process
        ssh.execute("dokku apps:create #{app_dokku_id}")
      end
    end
  end
end
