class ServerAction < ApplicationRecord
  include BelongsToOrg
  include BelongsToMembership
  include BelongsToServer
  include ServerActions::Processor

  belongs_to :actionable, polymorphic: true, optional: true

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  enum status: {
    pending: "pending",
    running: "running",
    success: "success",
    failure: "failure"
  }, _default: "pending"

  attribute :source, :string, default: "web"

  scope :pending_or_running, -> { where(status: %w[pending running]) }

  def perform
    raise "server action must implement #perform"
  end

  def concurrency_key
    actionable
  end

  def self.perform_later!(actionable, **)
    create!(actionable:, **).perform_later
  end

  def perform_later
    PerformServerActionJob.perform_later(self)
  end

  def completed?
    completed_at.present?
  end

  def duration
    return if running_at.blank? || completed_at.blank?

    completed_at - running_at
  end
end
