class Service < ApplicationRecord
  include Containerizable
  include Discard::Model
  include LogStreamable
  include ServerActionable

  TEMPORARY_STATUSES = %w[deleting restarting stopping].freeze

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :project, touch: true

  has_many :service_links, dependent: :destroy
  has_many :linked_apps, through: :service_links, source: :app

  store_attribute :data, :dsn, :string
  store_attribute :data, :version, :string

  str_enum :status, [:pending, :active, :restarting, :stopping, :stopped, :deleting, :deleted, :error], default: :pending
  str_enum :service_type, [:postgres, :redis, :mongo], validate: true

  validates :name, presence: true

  before_validation :set_default_name, on: :create
  before_create :set_dokku_id

  after_update_commit do
    broadcast_replace_later_to project, target: dom_id(self), partial: "projects/services/service", locals: {service: self}
  end

  def related_server_actions
    ServerAction.where(server_id:).where("json_extract(payload, '$.dokku_service_id') = ?", dokku_id)
  end

  def temporary_status?
    status.in?(TEMPORARY_STATUSES)
  end

  def container_name
    "dokku.#{service_type}.#{dokku_id}"
  end

  private

  def set_default_name
    return unless name.blank?
    return unless service_type.present?

    self.name = service_type.titleize

    while server.services.kept.exists?(name:)
      self.name = "#{service_type.titleize}-#{SecureRandom.hex(2)}"
    end
  end

  def set_dokku_id
    self.dokku_id = name.parameterize

    while server.services.kept.exists?(dokku_id:)
      self.dokku_id = "#{name.parameterize}-#{SecureRandom.hex(2)}"
    end
  end
end
