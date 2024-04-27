module Ssh
  class Command
    include StoreModel::Model

    attribute :command, :string
    attribute :finished_at, :datetime
    attribute :exit_code, :integer
    attribute :output, OutputEntry.to_array_type, default: -> { [] }
    attribute :started_at, :datetime

    validates :command, presence: true

    def append_output(stream, data)
      output << OutputEntry.new(timestamp: Time.current, stream: stream.to_s, data:)
    end

    def text_output
      output.map(&:data).join
    end

    def success?
      exit_code.zero?
    end

    def failure?
      !success?
    end

    def duration
      finished_at - started_at
    end
  end
end
