# == Schema Information
#
# Table name: services
#
#  id           :integer          not null, primary key
#  data         :json             not null
#  discarded_at :datetime
#  dokku_name   :string           not null
#  name         :string           not null
#  service_type :string           not null
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  org_id       :integer          not null
#  server_id    :integer          not null
#
# Indexes
#
#  index_services_on_org_id     (org_id)
#  index_services_on_server_id  (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
FactoryBot.define do
  factory :service do
    org { nil }
    server { nil }
    name { "MyString" }
    dokku_name { "MyString" }
    data { "" }
  end
end
