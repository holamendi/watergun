class App < ApplicationRecord
  include Actionable
  include BelongsToOrg
  include BelongsToServer
  include Containerizable
  include Discard::Model
  include DokkuEntity
  include EnvironmentConfigurable

  enum status: {
    initializing: "initializing",
    idle: "idle"
  }, _prefix: true, _default: :initializing

  has_one :deploy_source, dependent: :destroy
  has_many :service_links, dependent: :destroy
  has_many :services, through: :service_links

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  after_create_commit -> { enqueue_action!(:create, dokku_id:) }
  after_update_commit -> { broadcast_refresh_to(self) }
  after_discard -> { enqueue_action!(:destroy, dokku_id:) }

  def ssl_enabled?
    urls.any? { |url| url.start_with?("https://") }
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
