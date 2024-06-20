module Projects
  module Apps
    class MetricsController < BaseController
      def show
        @running_containers = current_app.containers.running
      end
    end
  end
end
