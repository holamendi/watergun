class Action < ApplicationRecord
  include BelongsToOrg
  include BelongsToMembership
  include BelongsToServer

  belongs_to :actionable, polymorphic: true, optional: true

  has_one :action_log, dependent: :destroy

  enum status: {
    pending: "pending",
    running: "running",
    success: "success",
    failure: "failure",
    exception: "exception"
  }, _prefix: true, _default: "pending"

  attribute :source, :string, default: "web"

  store_attribute :data, :exception, :json, default: {}

  scope :pending_or_running, -> { where(status: %w[pending running]) }

  def action_code
    type.delete_prefix("Actions::").underscore.tr("/", ".")
  end

  def enqueue
    Actions::ProcessJob.perform_later(self)
  end

  def process
    processor.call
  end

  def processor
    "Processors#{type.delete_prefix("Actions")}".constantize.new(self)
  end

  def completed?
    completed_at.present?
  end

  def duration
    return if running_at.blank? || completed_at.blank?

    completed_at - running_at
  end
end
