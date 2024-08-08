class Projects::Apps::MetricsController < Projects::Apps::BaseController
  def show
  end

  def stats
    @running_containers_count = current_app.containers.running.size
    @total_cpu_usage = current_app.containers.running.sum(:cpu_percentage).round(2)
    @memory_usage_percentage = current_app.containers.running.sum(:memory_percentage).round(2)
    @memory_usage_megabytes = IECByteSize.new(current_app.containers.running.sum(:memory_used_bytes))
    @memory_usage_limit_megabytes = IECByteSize.bytes(current_app.containers.running.last.memory_limit_bytes)
  end

  def cpu_chart
    @chart_data = current_app.containers.running.checked_within(from: 1.hour.ago).map do |container|
      {
        name: container.name,
        data: container.checks.where(timestamp: 1.hour.ago..).group_by_minute(:timestamp).average(:cpu_percentage)
      }
    end
  end

  def memory_chart
    @max_memory_megabytes = IECByteSize.bytes(current_app.containers.running.checked_within(from: 1.hour.ago).maximum(:memory_limit_bytes)).to_mib.round(2)
    @chart_data = current_app.containers.running.checked_within(from: 1.hour.ago).map do |container|
      {
        name: container.name,
        data: container.checks.where(timestamp: 1.hour.ago..).group_by_minute(:timestamp).average("ROUND(memory_used_bytes / 1048576.0, 2)")
      }
    end
  end
end
