module ActionProcessors
  module Apps
    class Restart < Base
      def process
        ssh.execute("dokku ps:restart #{action.dokku_id}")
      end
    end
  end
end
