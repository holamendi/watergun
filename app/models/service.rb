class Service < ApplicationRecord
  include Containerizable
  include Discard::Model
  include DokkuEntity
  include ServerActionable

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }

  has_many :service_links, dependent: :destroy
  has_many :linked_apps, through: :service_links, source: :app

  store_attribute :data, :version, :string

  enum service_type: {
    postgres: 0,
    redis: 1,
    mongo: 2
  }

  enum status: {
    pending: 0,
    created: 1,
    destroyed: 2
  }, _default: :pending, _prefix: true

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  after_update_commit -> { broadcast_refresh_to(self) }
end
