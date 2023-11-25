class App < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer
  include ServerEventable

  store_attribute :data, :git_repo, :string
  store_attribute :data, :git_branch, :string

  validates :name, presence: true, uniqueness: {scope: :server_id}

  before_validation :set_dokku_name, on: :create

  private

  def set_dokku_name
    self.dokku_name = "wgn-#{SecureRandom.hex(4)}"
  end
end
