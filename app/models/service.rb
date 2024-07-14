class Service < ApplicationRecord
  include Broadcast
  include Discard::Model
  include Containerizable
  include ServerActionable

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :project, touch: true

  has_many :service_links, dependent: :destroy
  has_many :linked_apps, through: :service_links, source: :app

  store_attribute :data, :version, :string

  str_enum :status, [:pending, :active, :restarting, :stopping, :stopped, :deleting, :deleted, :error], default: :pending
  str_enum :service_type, [:postgres, :redis, :mongo], validate: true

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  before_create do
    self.dokku_id ||= "#{name.parameterize}-#{SecureRandom.hex(2)}"
  end
end
