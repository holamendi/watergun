class System::MetricsCommand
  # Outputs 6 lines: cpu_usage, mem_used, mem_total, disk_used, disk_total, load_avg
  def cmd
    [
      cpu_usage,
      memory,
      disk,
      load_average
    ].join(" && ")
  end

  def parse_output(exit_code, text_output)
    return unless exit_code.zero?

    System::ServerStats.new(text_output)
  end

  private

  # Sample CPU twice with 0.5s delay to calculate usage percentage
  def cpu_usage
    <<~SH.squish
      awk '/^cpu / {u=$2+$4; t=$2+$4+$5; if(NR==1){u1=u;t1=t}else{print (u-u1)*100/(t-t1)}}'
      <(cat /proc/stat) <(sleep 0.5 && cat /proc/stat)
    SH
  end

  # Output mem_used and mem_total in bytes (2 lines)
  def memory
    "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print (t-a)*1024; print t*1024}' /proc/meminfo"
  end

  # Output disk_used and disk_total in bytes (2 lines)
  def disk
    "df -B1 / | awk 'NR==2 {print $3; print $2}'"
  end

  # Output 1-minute load average
  def load_average
    "awk '{print $1}' /proc/loadavg"
  end
end
