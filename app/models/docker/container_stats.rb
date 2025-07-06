class Docker::ContainerStats
  attr_reader :cpu_perc, :id, :mem_perc, :mem_usage, :mem_usage_bytes, :name, :net_io, :net_io_bytes, :block_io, :block_io_bytes

  def initialize(json)
    json = JSON.parse(json).transform_keys(&:underscore)

    @block_io = json["block_io"]
    @block_io_bytes = parse_size_string(json["block_io"])
    @cpu_perc = json["cpu_perc"].to_f.round(2)
    @mem_perc = json["mem_perc"].to_f.round(2)
    @mem_usage = json["mem_usage"]
    @mem_usage_bytes = parse_size_string(json["mem_usage"])
    @id = json["id"]
    @name = json["name"]
    @net_io = json["net_io"]
    @net_io_bytes = parse_size_string(json["net_io"])
  end

  private

  def parse_size_string(string)
    string.split(" / ").map do |value|
      ByteSize.new(value).to_bytes
    rescue
      0
    end
  end
end
