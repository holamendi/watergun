class App < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer
  include ServerEventable

  DOKKU_BUILDERS = {
    buildpack: "Heroku Buildpacks",
    dockerfile: "Dockerfile",
    nixpacks: "Nixpacks"
  }

  store_attribute :data, :git_repo, :string
  store_attribute :data, :git_branch, :string, default: "main"
  store_attribute :data, :dokku_builder, :string, default: "buildpack"

  validates :name, :git_repo, :git_branch, presence: true, uniqueness: {scope: :server_id}
  validates :dokku_builder, inclusion: {in: DOKKU_BUILDERS.keys}

  before_validation :set_dokku_name, on: :create

  private

  def set_dokku_name
    self.dokku_name = "wgn-#{SecureRandom.hex(4)}"
  end
end
