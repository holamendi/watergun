class ServerEventLogEntry
  include StoreModel::Model

  attribute :command, :string
  attribute :completed_at, :datetime
  attribute :exit_code, :integer
  attribute :output, :string
  attribute :started_at, :datetime

  def success?
    exit_code.zero?
  end
end
