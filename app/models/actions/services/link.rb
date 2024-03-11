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
module Actions
  module Services
    class Link < Action
      store_attribute :payload, :service_link_id, :integer
      store_attribute :payload, :service_type, :string
      store_attribute :payload, :service_dokku_id, :string
      store_attribute :payload, :app_dokku_id, :string

      validates :service_dokku_id, :app_dokku_id, :service_type, :service_link_id, presence: true
    end
  end
end
