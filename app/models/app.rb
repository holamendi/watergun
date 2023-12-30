# == Schema Information
#
# Table name: apps
#
#  id         :integer          not null, primary key
#  data       :json             not null
#  dokku_name :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  org_id     :integer          not null
#  server_id  :integer          not null
#
# Indexes
#
#  index_apps_on_org_id     (org_id)
#  index_apps_on_server_id  (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
class App < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer
  include ServerEventable

  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  store_attribute :data, :git_repo, :string
  store_attribute :data, :git_branch, :string, default: "main"
  store_attribute :data, :dokku_builder, :string, default: "buildpack"

  validates :name, presence: true, uniqueness: {scope: :server_id}
  validates :git_repo, :git_branch, presence: true
  validates :dokku_builder, inclusion: {in: DOKKU_BUILDERS.keys}

  before_validation :set_dokku_name, on: :create

  def available_dokku_builders
    DOKKU_BUILDERS if server.architecture.include?("x86")

    DOKKU_BUILDERS.except("buildpack")
  end

  private

  def set_dokku_name
    self.dokku_name = "wgn-#{name.parameterize}-#{SecureRandom.hex(2)}"
  end
end
