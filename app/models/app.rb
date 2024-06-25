class App < ApplicationRecord
  include Discard::Model
  include Containerizable
  include ServerActionable

  belongs_to :org, default: -> { Current.org }
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

  str_enum :status, [:pending, :active, :deploying, :restarting, :stopping, :stopped, :deleting, :deleted, :error], default: :pending

  validates :name, presence: true, uniqueness: {scope: :project_id, conditions: -> { undiscarded }}

  scope :deployed, -> { where.not(deployed_at: nil) }

  before_create do
    self.dokku_id = "#{name.parameterize}-#{SecureRandom.hex(2)}"
  end

  after_update_commit do
    broadcast_refresh_to(self)
  end

  accepts_nested_attributes_for :github_repo

  def pending_restart!
    update!(pending_restart: true)
  end

  def deployed?
    deployed_at.present?
  end
end
