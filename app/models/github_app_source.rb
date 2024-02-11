# == Schema Information
#
# Table name: app_sources
#
#  id         :integer          not null, primary key
#  data       :json             not null
#  type       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :integer          not null
#  org_id     :integer          not null
#
# Indexes
#
#  index_app_sources_on_app_id  (app_id)
#  index_app_sources_on_org_id  (org_id)
#
# Foreign Keys
#
#  app_id  (app_id => apps.id)
#  org_id  (org_id => orgs.id)
#
class GithubAppSource < AppSource
  store_attribute :data, :repo, :string
  store_attribute :data, :branch, :string, default: "main"

  validates :repo, :branch, presence: true
end
