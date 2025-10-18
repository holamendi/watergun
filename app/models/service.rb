class Service < ApplicationRecord
  include ServerActionable
  include LogStreamable
  include Discard::Model
  include Containerizable

  TEMPORARY_STATUSES = %i[pending deleting restarting stopping].freeze

  belongs_to :account, default: -> { server.account }
  belongs_to :server
  belongs_to :project, touch: true

  has_many :service_links, dependent: :destroy
  has_many :linked_apps, through: :service_links, source: :app

  store_attribute :data, :dsn, :string
  store_attribute :data, :version, :string

  enum :status, Enum[:pending, :active, :restarting, :stopping, :stopped, :deleting, :deleted, :error], default: :pending
  enum :service_type, Enum[*Dokku::Plugin::InstallCommand::PLUGINS.keys], validate: true

  validates :name, presence: true

  before_create :set_dokku_id

  after_update_commit do
    broadcast_replace_later_to self, target: dom_id(self, :header), partial: "projects/services/header", locals: {service: self}
    broadcast_replace_later_to self, target: dom_id(self, :form), partial: "projects/services/form", locals: {service: self}
    broadcast_replace_later_to project, target: dom_id(self), partial: "projects/services/service", locals: {service: self}
  end

  def temporary_status?
    status.to_sym.in?(TEMPORARY_STATUSES)
  end

  private

  def set_dokku_id
    self.dokku_id = name.parameterize.dasherize

    loop do
      break unless server.services.kept.exists?(dokku_id:)
      self.dokku_id = "#{name.parameterize}-#{SecureRandom.hex(4)}"
    end
  end
end
