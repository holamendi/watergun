class Service < ApplicationRecord
  include ServerActionable
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
  }

  enum status: {
    pending: "pending",
    created: "created"
  }, _default: "pending"

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  after_update_commit -> { broadcast_refresh_to(self) }
end
