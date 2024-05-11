class App < ApplicationRecord
  include Containerizable
  include Discard::Model
  include DokkuEntity
  include EnvConfigurable
  include ServerActionable

  has_paper_trail

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }

  has_many :deployments, dependent: :delete_all
  has_one :deployment, -> { success.order(created_at: :desc) }, class_name: "Deployment"
  has_one :github_repo, dependent: :destroy
  has_many :service_links, dependent: :delete_all
  has_many :services, through: :service_links

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}
  after_update_commit -> { broadcast_refresh_to(self) }

  def ssl_enabled?
    https_urls.any?
  end

  def https_urls
    urls.to_a.select { |url| url.start_with?("https://") }
  end

  def url
    https_urls.first || urls.first
  end

  def urls_resolve_to_server?
    urls.all? { |url| Resolv.getaddress(URI.parse(url).host) == server.public_ip }
  end
end
