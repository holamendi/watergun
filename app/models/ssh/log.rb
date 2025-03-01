class Ssh::Log
  attr_reader :timestamp, :stream, :data

  def initialize(stream:, data:, timestamp: Time.current)
    @stream = stream
    @data = data
    @timestamp = timestamp
  end

  def self.from_json(json) = new(**json.symbolize_keys)

  def as_json
    {
      timestamp:,
      stream:,
      data:
    }
  end
end
