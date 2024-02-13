# == Schema Information
#
# Table name: apps
#
#  id           :integer          not null, primary key
#  data         :json             not null
#  discarded_at :datetime
#  name         :string           not null
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  dokku_id     :string           not null
#  org_id       :integer          not null
#  server_id    :integer          not null
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
  include Discard::Model
  include DokkuEntity

  store_attribute :data, :urls, :json, default: []

  enum status: {
    initializing: "initializing",
    idle: "idle"
  }, _prefix: true, _default: :initializing

  has_many :sources, class_name: "AppSource", dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}

  after_create_commit -> { create_and_enqueue_action!(:create) }
  after_update_commit -> { broadcast_refresh_to self }
  after_discard -> { create_and_enqueue_action!(:destroy) }

  def compatible_dokku_builders
    if server.architecture.include?("x86")
      Server::DOKKU_BUILDERS
    else
      Server::DOKKU_BUILDERS.except("herokuish")
    end
  end

  def ssl_enabled?
    urls.any? { |url| url.start_with?("https://") }
  end

  def https_urls
    urls.select { |url| url.start_with?("https://") }
  end

  def url
    https_urls.first || urls.first
  end
end
