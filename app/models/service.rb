class Service < ApplicationRecord
  include Containerizable
  include Discard::Model
  include DokkuEntity
  include ServerActionable

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }
  belongs_to :project

  has_many :service_links, dependent: :destroy
  has_many :linked_apps, through: :service_links, source: :app

  store_attribute :data, :version, :string

  str_enum :status, [:pending, :active, :restarting, :stopping, :stopped, :deleting, :deleted, :error], default: :pending
  str_enum :service_type, [:postgres, :redis, :mongo], validate: true

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  after_create_commit -> { ServerActions::CreateService.perform_later!(self) }

  after_update_commit -> do
    broadcast_refresh_to(project)
    broadcast_refresh_to(self)
  end
end
