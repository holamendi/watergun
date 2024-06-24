class App < ApplicationRecord
  include Containerizable
  include Discard::Model
  include DokkuEntity
  include EnvConfigurable
  include ServerActionable

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }
  belongs_to :project

  has_many :domains, dependent: :delete_all
  has_many :deployments, dependent: :delete_all
  has_one :deployment, -> { success.recent }
  has_one :github_repo, dependent: :destroy
  has_many :service_links, dependent: :destroy
  has_many :services, through: :service_links

  str_enum :status, [:pending, :active, :deploying, :restarting, :stopping, :stopped, :deleting, :deleted, :error], default: :pending

  validates :name, presence: true, uniqueness: {scope: :project_id, conditions: -> { undiscarded }}

  accepts_nested_attributes_for :github_repo

  after_create_commit -> { ServerActions::CreateApp.perform_later!(self) }

  after_update_commit -> do
    broadcast_refresh_to(project)
    broadcast_refresh_to(self)
  end

  after_discard do
    service_links.discard_all
    ServerActions::DestroyApp.perform_later!(self)
  end

  def deployed?
    deployed_at.present?
  end

  memoize def url
    domains.ssl_enabled.first&.url || domains.first&.url
  end
end
