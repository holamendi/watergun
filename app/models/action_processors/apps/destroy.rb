module ActionProcessors
  module Apps
    class Destroy < Base
      def process
        execute("dokku apps:destroy --force #{action.dokku_id}")
      end
    end
  end
end
