class Service < ApplicationRecord
  include Actionable
  include BelongsToOrg
  include BelongsToServer
  include Containerizable
  include Discard::Model
  include DokkuEntity

  has_many :service_links, dependent: :destroy
  has_many :linked_apps, through: :service_links, source: :app

  enum service_type: {
    postgres: "postgres",
    redis: "redis"
  }, _prefix: true

  enum status: {
    pending: "pending",
    created: "created"
  }, _prefix: true, _default: "pending"

  after_create_commit -> { enqueue_action!(:create, dokku_id:, service_type:) }
  after_discard -> { enqueue_action!(:destroy, dokku_id:, service_type:) }
  after_update_commit -> { broadcast_refresh_to(self) }

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}
end
