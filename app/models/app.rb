# == Schema Information
#
# Table name: apps
#
#  id               :integer          not null, primary key
#  data             :json             not null
#  discarded_at     :datetime
#  last_deployed_at :datetime
#  name             :string           not null
#  status           :string
#  urls             :json
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  dokku_id         :string           not null
#  org_id           :integer          not null
#  server_id        :integer          not null
#
# Indexes
#
#  index_apps_on_discarded_at  (discarded_at)
#  index_apps_on_org_id        (org_id)
#  index_apps_on_server_id     (server_id)
#  index_apps_on_status        (status)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
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
