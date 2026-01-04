class System::ServerStats
  attr_reader :cpu_usage, :memory_usage, :memory_used_bytes, :memory_total_bytes,
    :disk_usage, :disk_used_bytes, :disk_total_bytes, :load_average

  # Parses 6 lines: cpu_usage, mem_used, mem_total, disk_used, disk_total, load_avg
  def initialize(output)
    lines = output.lines.map(&:strip)

    @cpu_usage = lines[0].to_f.round(2)
    @memory_used_bytes = lines[1].to_i
    @memory_total_bytes = lines[2].to_i
    @disk_used_bytes = lines[3].to_i
    @disk_total_bytes = lines[4].to_i
    @load_average = lines[5].to_f.round(2)

    @memory_usage = percentage(@memory_used_bytes, @memory_total_bytes)
    @disk_usage = percentage(@disk_used_bytes, @disk_total_bytes)
  end

  private

  def percentage(used, total)
    return 0.0 if total.zero?
    ((used.to_f / total) * 100).round(2)
  end
end
