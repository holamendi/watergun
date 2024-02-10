# == Schema Information
#
# Table name: actions
#
#  id              :integer          not null, primary key
#  actionable_type :string
#  args            :json             not null
#  completed_at    :datetime
#  data            :json             not null
#  event_type      :string           not null
#  running_at      :datetime
#  source          :string           not null
#  status          :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  actionable_id   :integer
#  job_id          :string
#  membership_id   :integer
#  org_id          :integer          not null
#  server_id       :integer          not null
#
# Indexes
#
#  index_actions_on_membership_id     (membership_id)
#  index_actions_on_org_id            (org_id)
#  index_actions_on_server_id         (server_id)
#  index_server_events_on_actionable  (actionable_type,actionable_id)
#
# Foreign Keys
#
#  membership_id  (membership_id => memberships.id)
#  org_id         (org_id => orgs.id)
#  server_id      (server_id => servers.id)
#
class Action < ApplicationRecord
  include BelongsToOrg
  include BelongsToMembership
  include BelongsToServer

  belongs_to :actionable, polymorphic: true, optional: true, touch: true

  has_one :action_log, dependent: :destroy

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

  validates :event_type, inclusion: {in: -> { _1.event_types }}, if: -> { eventable.present? }

  after_create_commit -> { server_event_log&.update!(server_event_id: id) }

  after_create_commit :process_async
  after_create_commit -> { broadcast_prepend_to eventable, :server_events }
  after_update_commit -> { broadcast_replace_to eventable, :server_events }

  def completed?
    completed_at.present?
  end

  def duration
    return if running_at.blank? || completed_at.blank?

    completed_at - running_at
  end

  def process_async
    Actions::ProcessJob.perform_later(self)
  end

  def process
    event_processor.new(self).call
  end

  def event_processor
    "Actions::#{eventable.class.name.pluralize}::#{event_type.classify}".constantize
  end

  def event_types
    eventable.class::SERVER_EVENT_TYPES
  end
end
