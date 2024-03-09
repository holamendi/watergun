# == Schema Information
#
# Table name: deploy_sources
#
#  id         :integer          not null, primary key
#  active     :boolean
#  data       :json
#  type       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :integer          not null
#  org_id     :integer          not null
#
# Indexes
#
#  index_deploy_sources_on_app_id  (app_id)
#  index_deploy_sources_on_org_id  (org_id)
#
# Foreign Keys
#
#  app_id  (app_id => apps.id)
#  org_id  (org_id => orgs.id)
#
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
