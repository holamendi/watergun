module MetrizableController
  extend ActiveSupport::Concern

  def stats
    containers_data = running_containers.select(
      :id, :name, :cpu_percentage, :memory_percentage, :memory_used_bytes, :memory_limit_bytes
    )
    
    aggregates = containers_data.pick(
      'SUM(cpu_percentage) as total_cpu',
      'SUM(memory_percentage) as total_memory',
      'SUM(memory_used_bytes) as total_memory_bytes',
      'MAX(memory_limit_bytes) as max_limit_bytes'
    )
    
    render partial: "metrics/stats", locals: {
      containers: containers_data,
      total_cpu_usage: (aggregates['total_cpu'] || 0).round(2),
      memory_usage_percentage: (aggregates['total_memory'] || 0).round(2),
      memory_usage_megabytes: IECByteSize.new(aggregates['total_memory_bytes'] || 0),
      memory_usage_limit_megabytes: aggregates['max_limit_bytes'] ? IECByteSize.bytes(aggregates['max_limit_bytes']) : 0
    }
  end

  def cpu_chart
    from_time = 1.hour.ago
    
    data = containers.checked_within(from: from_time)
      .joins(:checks)
      .where(checks: { timestamp: from_time.. })
      .group('containers.id', 'containers.name')
      .group_by_minute('checks.timestamp')
      .average('checks.cpu_percentage')
      .group_by { |key, _| key[0..1] }
      .map do |(container_id, container_name), grouped_data|
        {
          name: container_name,
          data: grouped_data.transform_keys { |key| key[2] }.transform_values(&:round)
        }
      end

    render partial: "metrics/cpu_chart", locals: {data:}
  end

  def memory_chart
    from_time = 1.hour.ago
    
    memory_limit_bytes = containers.checked_within(from: from_time).maximum(:memory_limit_bytes) || 0
    
    data = containers.checked_within(from: from_time)
      .joins(:checks)
      .where(checks: { timestamp: from_time.. })
      .group('containers.id', 'containers.name')
      .group_by_minute('checks.timestamp')
      .average('ROUND(checks.memory_used_bytes / 1048576.0, 2)')
      .group_by { |key, _| key[0..1] }
      .map do |(container_id, container_name), grouped_data|
        {
          name: container_name,
          data: grouped_data.transform_keys { |key| key[2] }
        }
      end

    render partial: "metrics/memory_chart", locals: {data:, max: IECByteSize.bytes(memory_limit_bytes).to_mib.round(2)}
  end

  private

  def containerizable
    raise "implement in class"
  end

  def containers
    containerizable.containers
  end

  def running_containers
    containers.running
  end
end
