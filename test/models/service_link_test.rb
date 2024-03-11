# == Schema Information
#
# Table name: service_links
#
#  id           :integer          not null, primary key
#  discarded_at :datetime
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  app_id       :integer          not null
#  org_id       :integer          not null
#  service_id   :integer          not null
#
# Indexes
#
#  index_service_links_on_app_id                 (app_id)
#  index_service_links_on_discarded_at           (discarded_at)
#  index_service_links_on_org_id                 (org_id)
#  index_service_links_on_service_id             (service_id)
#  index_service_links_on_service_id_and_app_id  (service_id,app_id) UNIQUE
#
# Foreign Keys
#
#  app_id      (app_id => apps.id)
#  org_id      (org_id => orgs.id)
#  service_id  (service_id => services.id)
#
require "test_helper"

class ServiceLinkTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
