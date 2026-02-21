class App < ApplicationRecord
  include Discard::Model
  include Containerizable
  include LogStreamable
  include ServerActionable

  has_secure_token :deploy_token, length: 32

  TEMPORARY_STATUSES = %w[deploying restarting scaling stopping].freeze

  belongs_to :account, default: -> { project.account }
  belongs_to :server, default: -> { project.server }
  belongs_to :project, touch: true

  has_many :domains, dependent: :destroy
  has_one :default_domain, -> { default }, class_name: "Domain"

  has_many :deployments, dependent: :destroy
  has_one :deployment, -> { success.recent }

  has_many :env_variables, dependent: :destroy
  has_many :storage_mounts, dependent: :destroy

  has_one :github_repo, class_name: "Github::Repo", dependent: :destroy

  has_many :service_links, dependent: :destroy
  has_many :services, through: :service_links

  enum :builder, Enum[:herokuish, :dockerfile, :nixpacks], default: :herokuish
  enum :status, Enum[:pending, :active, :deploying, :restarting, :scaling, :stopping, :deleted, :error], default: :pending

  scope :deployed, -> { where.not(deployed_at: nil) }

  before_create :set_dokku_id

  after_update_commit do
    broadcast_replace_later_to self, target: dom_id(self, :header), partial: "projects/apps/header", locals: {app: self}
    broadcast_replace_later_to project, target: dom_id(self), partial: "projects/apps/app", locals: {app: self}
  end

  delegate :github_installation, to: :account

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

    loop do
      break unless server.apps.kept.exists?(dokku_id:)
      self.dokku_id = "#{name.parameterize}-#{SecureRandom.hex(4)}"
    end
  end
end
