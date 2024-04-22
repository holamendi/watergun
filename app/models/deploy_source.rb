class DeploySource < ApplicationRecord
  include BelongsToOrg

  belongs_to :app, inverse_of: :deploy_source

  delegate :dokku_id, to: :app
end
