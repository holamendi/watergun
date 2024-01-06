# == Schema Information
#
# Table name: server_events
#
#  id             :integer          not null, primary key
#  args           :json             not null
#  completed_at   :datetime
#  data           :json             not null
#  event_type     :string           not null
#  eventable_type :string
#  running_at     :datetime
#  source         :string           not null
#  status         :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  eventable_id   :integer
#  job_id         :string
#  membership_id  :integer
#  org_id         :integer          not null
#  server_id      :integer          not null
#
# Indexes
#
#  index_server_events_on_eventable      (eventable_type,eventable_id)
#  index_server_events_on_membership_id  (membership_id)
#  index_server_events_on_org_id         (org_id)
#  index_server_events_on_server_id      (server_id)
#
# Foreign Keys
#
#  membership_id  (membership_id => memberships.id)
#  org_id         (org_id => orgs.id)
#  server_id      (server_id => servers.id)
#
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
    failure: "failure",
    exception: "exception"
  }, _prefix: true, _default: "pending"

  attribute :source, :string, default: "web"

  store_attribute :data, :details, :json, default: []
  store_attribute :data, :exception, :json, default: {}

  validates :event_type, inclusion: {in: EVENT_TYPES}

  after_create_commit :process_async
  after_create_commit -> { broadcast_prepend_to eventable, :server_events }
  after_update_commit -> { broadcast_replace_to eventable, :server_events }

  def completed?
    completed_at.present?
  end

  def process_async
    ServerEvents::ProcessJob.perform_later(self)
  end

  def process
    event_processor.new(self).call
  end

  def event_processor
    "ServerEvents::#{event_type.split(".").map(&:camelize).join("::")}".constantize
  end
end
