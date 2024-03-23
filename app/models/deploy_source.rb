class DeploySource < ApplicationRecord
  include BelongsToOrg

  belongs_to :app, inverse_of: :deploy_source

  delegate :dokku_id, to: :app

  def source_type
    type.demodulize.downcase
  end

  def model_name
    ActiveModel::Name.new(DeploySource)
  end
end
