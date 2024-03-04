module ActionProcessors
  module Apps
    class Create < Base
      def process
        execute("dokku apps:create #{action.dokku_id}")
      end
    end
  end
end
