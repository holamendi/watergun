class ServerEvent < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  belongs_to :eventable, polymorphic: true, optional: true
  belongs_to :membership, optional: true

  has_one :server_event_log, dependent: :destroy

  enum status: {
    pending: "pending",
    running: "running",
    success: "success",
    failure: "failure"
  }, _prefix: true, _default: "pending"

  def enqueue!
    update(job_id: ServerEvents::ProcessJob.perform_later(self))
  end
end
