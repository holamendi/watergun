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
module DeploySources
  class Github < DeploySource
    store_attribute :data, :repository, :string
    store_attribute :data, :branch, :string, default: "main"

    validates :repository, :data, presence: true

    def model_name
      ActiveModel::Name.new(DeploySource)
    end
  end
end
