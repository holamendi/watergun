class ServerEvent < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  EVENT_TYPES = %w[
    apps.create
    apps.deploy
    apps.destroy
    apps.restart
  ]

  belongs_to :eventable, polymorphic: true, optional: true
  belongs_to :membership, optional: true

  has_one :server_event_log, dependent: :destroy

  enum status: {
    pending: "pending",
    running: "running",
    success: "success",
    failure: "failure"
  }, _prefix: true, _default: "pending"

  validates :event_type, inclusion: {in: EVENT_TYPES}

  after_create_commit :enqueue

  after_create_commit -> { broadcast_prepend_to eventable, :server_events }
  after_update_commit -> { broadcast_replace_to eventable, :server_events }

  def completed?
    completed_at.present?
  end

  def enqueue
    ServerEvents::ProcessJob.perform_later(self)
  end

  def event_processor
    "ServerEvents::#{event_type.split(".").map(&:camelize).join("::")}".constantize
  end
end
