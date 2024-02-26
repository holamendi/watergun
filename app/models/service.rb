# == Schema Information
#
# Table name: services
#
#  id           :integer          not null, primary key
#  data         :json             not null
#  discarded_at :datetime
#  name         :string           not null
#  service_type :string           not null
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  dokku_id     :string
#  org_id       :integer          not null
#  server_id    :integer          not null
#
# Indexes
#
#  index_services_on_org_id     (org_id)
#  index_services_on_server_id  (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
class Service < ApplicationRecord
  include Actionable
  include BelongsToOrg
  include BelongsToServer
  include Containerizable
  include Discard::Model
  include DokkuEntity

  enum service_type: {
    postgres: "postgres",
    redis: "redis"
  }, _prefix: true

  after_create_commit -> { create_and_enqueue_action!(:create) }
  after_discard -> { create_and_enqueue_action!(:destroy) }
  after_update_commit -> { broadcast_refresh_to(self) }

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  def restart!
    create_server_event!("restart")
  end
end
