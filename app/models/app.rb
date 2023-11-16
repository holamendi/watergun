class App < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer
  include ServerEventable

  validates :name, presence: true, uniqueness: {scope: :server_id}

  before_validation :set_dokku_name, on: :create

  private

  def set_dokku_name
    self.dokku_name = name&.parameterize
  end
end
