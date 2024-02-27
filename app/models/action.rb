# == Schema Information
#
# Table name: actions
#
#  id              :integer          not null, primary key
#  actionable_type :string
#  args            :json             not null
#  completed_at    :datetime
#  data            :json             not null
#  payload         :json             not null
#  running_at      :datetime
#  source          :string           not null
#  status          :string           not null
#  type            :string
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
  include Actions::Processable
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

  def enqueue
    Actions::ProcessJob.perform_later(self)
  end

  def process
    processor_class.new(self).call
  end

  def processor_class
    "ActionProcessors::#{actionable.class.name.pluralize}::#{action_type.classify}"
  end

  def completed?
    completed_at.present?
  end

  def duration
    return if running_at.blank? || completed_at.blank?

    completed_at - running_at
  end
end
