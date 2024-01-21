# == Schema Information
#
# Table name: apps
#
#  id           :integer          not null, primary key
#  data         :json             not null
#  discarded_at :datetime
#  dokku_name   :string           not null
#  name         :string           not null
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
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
  include ServerEventable

  SERVER_EVENT_TYPES = %w[
    create
    deploy
    destroy
    restart
  ].freeze

  store_attribute :data, :git_repo, :string
  store_attribute :data, :git_branch, :string, default: "main"
  store_attribute :data, :dokku_builder, :string, default: "herokuish"

  validates :name, presence: true, uniqueness: {scope: :server_id, conditions: -> { undiscarded }}
  validates :git_repo, :git_branch, presence: true
  validates :dokku_builder, inclusion: {in: Server::DOKKU_BUILDERS.keys}

  before_validation :set_dokku_name, on: :create

  after_create_commit -> { server_events.create!(event_type: "create") }
  after_discard -> { server_events.create!(event_type: "destroy") }
  after_update_commit -> { broadcast_replace_to self, :header, target: "header_app_#{id}", partial: "apps/header", locals: {app: self} }

  def compatible_dokku_builders
    if server.architecture.include?("x86")
      Server::DOKKU_BUILDERS
    else
      Server::DOKKU_BUILDERS.except("herokuish")
    end
  end

  def deploy!
    update!(status: "deploying")
    server_events.create!(event_type: "apps.deploy")
  end

  def restart!
    update!(status: "restarting")
    server_events.create!(event_type: "apps.restart")
  end

  private

  def set_dokku_name
    self.dokku_name = "wgn-#{name.parameterize}-#{SecureRandom.hex(2)}"
  end
end
