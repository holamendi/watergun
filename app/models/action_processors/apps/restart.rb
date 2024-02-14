module ActionProcessors
  module Apps
    class Restart < Base
      def process
        execute("dokku ps:restart #{actionable.dokku_id}")
      end
    end
  end
end
