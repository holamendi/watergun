module Docker
  class Stat
    attr_reader :block_io,
      :cpu_percentage,
      :id,
      :memory_percentage,
      :memory_usage,
      :name,
      :network_io

    def initialize(stats_hash)
      stats_hash.transform_keys! { |key| key.underscore.to_sym }
      @block_io = stats_hash[:block_io]
      @cpu_percentage = stats_hash[:cpu_perc].to_f
      @id = stats_hash[:id]
      @memory_percentage = stats_hash[:mem_perc].to_f
      @memory_usage = stats_hash[:mem_usage]
      @name = stats_hash[:name]
      @network_io = stats_hash[:net_io]
    end
  end
end
