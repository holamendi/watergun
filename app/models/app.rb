class App < ApplicationRecord
  include Broadcast
  include Discard::Model
  include Containerizable
  include LogStreamable
  include ServerActionable

  TEMPORARY_STATUSES = %w[deploying restarting scaling stopping].freeze

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :project, touch: true
  has_many :domains, dependent: :delete_all
  has_one :default_domain, -> { default }, class_name: "Domain"
  has_many :deployments, dependent: :delete_all
  has_one :deployment, -> { success.recent }
  has_many :env_variables, dependent: :destroy
  has_one :github_repo, dependent: :destroy
  has_many :service_links, dependent: :destroy
  has_many :services, through: :service_links

  str_enum :builder, [:herokuish, :dockerfile, :nixpacks], default: :herokuish
  str_enum :status, [:pending, :active, :deploying, :restarting, :scaling, :stopping, :stopped, :deleting, :deleted, :error], default: :pending

  validates :name, presence: true, uniqueness: {scope: :project_id, conditions: -> { undiscarded }}

  scope :deployed, -> { where.not(deployed_at: nil) }

  accepts_nested_attributes_for :github_repo

  before_create :set_dokku_id

  def related_server_actions
    ServerAction.where("json_extract(payload, '$.dokku_app_id') = ?", dokku_id)
  end

  def pending_restart!
    update!(pending_restart: true)
  end

  def deployed?
    deployed_at.present?
  end

  def all_domains_resolve_to_server?
    domains.kept.all?(&:resolves_to_server?)
  end

  def temporary_status?
    status.in?(TEMPORARY_STATUSES)
  end

  private

  def set_dokku_id
    self.dokku_id = name.parameterize.dasherize

    while server.apps.kept.exists?(dokku_id:)
      self.dokku_id = "#{name.parameterize.dasherize}-#{SecureRandom.hex(2)}"
    end
  end
end
