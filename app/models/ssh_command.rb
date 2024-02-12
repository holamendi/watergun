class SshCommand
  include StoreModel::Model

  attribute :command, :string
  attribute :completed_at, :datetime
  attribute :exit_code, :integer
  attribute :output, default: []
  attribute :started_at, :datetime

  validates :command, presence: true

  def text_output
    output.map(&:last).join
  end

  def success?
    exit_code.zero?
  end

  def failure?
    !success?
  end

  def duration
    completed_at - started_at
  end
end
