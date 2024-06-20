class App < ApplicationRecord
  include Containerizable
  include Discard::Model
  include DokkuEntity
  include EnvConfigurable
  include ServerActionable

  has_paper_trail

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }
  belongs_to :project

  has_many :domains, dependent: :delete_all
  has_many :deployments, dependent: :delete_all
  has_one :deployment, -> { success.recent }
  has_one :github_repo, dependent: :destroy
  has_many :service_links, dependent: :delete_all
  has_many :services, through: :service_links

  validates :name, presence: true, uniqueness: {scope: :project_id, conditions: -> { undiscarded }}
  after_update_commit -> { broadcast_refresh_to(self) }

  accepts_nested_attributes_for :github_repo, allow_destroy: true

  def deployed?
    deployed_at.present?
  end

  memoize def url
    domains.ssl_enabled.first&.url || domains.first&.url
  end
end
