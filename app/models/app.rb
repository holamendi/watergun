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
  include BelongsToOrg
  include BelongsToServer
  include Discard::Model
  include DokkuEntity
  include ServerEventable

  SERVER_EVENT_TYPES = %w[
    create
    deploy
    destroy
    disable_ssl
    enable_ssl
    restart
    update
  ].freeze

  store_attribute :data, :git_repo, :string
  store_attribute :data, :git_branch, :string, default: "main"
  store_attribute :data, :dokku_builder, :string, default: "herokuish"
  store_attribute :data, :urls, :json, default: []

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}
  validates :git_repo, :git_branch, presence: true
  validates :dokku_builder, inclusion: {in: Server::DOKKU_BUILDERS.keys}

  after_create_commit -> { create_server_event!("create") }
  after_update -> { create_server_event!("update") }, if: -> { saved_change_to_git_repo? || saved_change_to_git_branch? || saved_change_to_dokku_builder? }
  after_update_commit -> { broadcast_refresh_to self, :header }
  after_discard -> { create_server_event!("destroy") }

  def compatible_dokku_builders
    if server.architecture.include?("x86")
      Server::DOKKU_BUILDERS
    else
      Server::DOKKU_BUILDERS.except("herokuish")
    end
  end

  def deploy!
    create_server_event!("deploy")
  end

  def restart!
    create_server_event!("restart")
  end

  def enable_ssl!
    create_server_event!("enable_ssl")
  end

  def disable_ssl!
    create_server_event!("disable_ssl")
  end

  def ssl_enabled?
    urls.any? { _1.start_with?("https://") }
  end

  def https_urls
    urls.select { _1.start_with?("https://") }
  end

  def url
    https_urls.first || urls.first
  end
end
