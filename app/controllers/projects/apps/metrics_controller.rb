module Projects
  module Apps
    class MetricsController < BaseController
      def show
      end

      def stats
        @running_containers_count = current_app.containers.running.size
        @total_cpu_usage = current_app.containers.running.sum(:cpu_percentage).round(2)
        @total_memory_usage = current_app.containers.running.sum(:memory_percentage).round(2)
      end

      def cpu_chart
        @chart_data = current_app.containers.running.checked_within(from: 1.hour.ago).map do |container|
          {
            name: container.name,
            data: container.checks
              .where(timestamp: 1.hour.ago..)
              .group_by_minute(:timestamp)
              .average(:cpu_percentage)
          }
        end
      end

      def memory_chart
        @chart_data = current_app.containers.running.checked_within(from: 1.hour.ago).map do |container|
          {
            name: container.name,
            data: container.checks
              .where(timestamp: 1.hour.ago..)
              .group_by_minute(:timestamp)
              .average(:memory_percentage)
          }
        end
      end
    end
  end
end
