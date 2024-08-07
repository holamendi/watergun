module Docker
  class ContainerStats
    include Memery

    UNIT_MULTIPLIERS = {
      "b" => 1,
      "k" => 1024,
      "kib" => 1024,
      "kb" => 1000,
      "m" => 1024**2,
      "mib" => 1024**2,
      "mb" => 1000**2,
      "g" => 1024**3,
      "gib" => 1024**3,
      "gb" => 1000**3,
      "t" => 1024**4,
      "tib" => 1024**4,
      "tb" => 1000**4
    }

    def initialize(json)
      @json = JSON.parse(json)
    end

    def block_io
      @json["BlockIO"]
    end

    memoize def block_io_bytes
      size_string_to_bytes(block_io)
    end

    def cpu_perc
      @json["CPUPerc"].to_f.round(2)
    end

    def id
      @json["ID"]
    end

    def mem_perc
      @json["MemPerc"].to_f.round(2)
    end

    def mem_usage
      @json["MemUsage"]
    end

    memoize def mem_usage_bytes
      size_string_to_bytes(mem_usage)
    end

    def name
      @json["Name"]
    end

    def net_io
      @json["NetIO"]
    end

    memoize def net_io_bytes
      size_string_to_bytes(net_io)
    end

    private

    def size_string_to_bytes(string)
      string.split(" / ").map do |value|
        size = value.to_f
        unit = value.delete(size.to_s)

        (size * UNIT_MULTIPLIERS[unit.downcase]).ceil
      end
    end
  end
end
