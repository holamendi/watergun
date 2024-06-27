module Projects
  module Apps
    class MetricsController < BaseController
      def show
        @containers = current_app.containers.checked_within(from: 1.hour.ago)
      end

      def cpu_usage
      end

      def memory_usage
      end
    end
  end
end
