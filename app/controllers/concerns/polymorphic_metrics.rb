module PolymorphicMetrics
  extend ActiveSupport::Concern

  def stats
    render partial: "metrics/stats", locals: {
      running_containers_count: containers.size,
      total_cpu_usage: containers.sum(:cpu_percentage).round(2),
      memory_usage_percentage: containers.sum(:memory_percentage).round(2),
      memory_usage_megabytes: IECByteSize.new(containers.sum(:memory_used_bytes)),
      memory_usage_limit_megabytes: IECByteSize.bytes(containers.last.memory_limit_bytes)
    }
  end

  def cpu_chart
    data = containers.checked_within(from: 1.hour.ago).map do |container|
      {
        name: container.name,
        data: container.checks.where(timestamp: 1.hour.ago..).group_by_minute(:timestamp).average(:cpu_percentage)
      }
    end

    render partial: "metrics/cpu_chart", locals: {data:}
  end

  def memory_chart
    max_memory_megabytes = IECByteSize.bytes(containers.checked_within(from: 1.hour.ago).maximum(:memory_limit_bytes)).to_mib.round(2)
    data = containers.checked_within(from: 1.hour.ago).map do |container|
      {
        name: container.name,
        data: container.checks.where(timestamp: 1.hour.ago..).group_by_minute(:timestamp).average("ROUND(memory_used_bytes / 1048576.0, 2)")
      }
    end

    render partial: "metrics/memory_chart", locals: {data:, max_memory_megabytes:}
  end

  private

  def containarizable
    raise "implement in subclass"
  end

  def containers
    containarizable.containers.running
  end
end
