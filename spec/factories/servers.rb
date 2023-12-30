# == Schema Information
#
# Table name: servers
#
#  id          :integer          not null, primary key
#  data        :json
#  dokku_token :string           not null
#  name        :string           not null
#  provider    :string           not null
#  status      :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  org_id      :integer          not null
#
# Indexes
#
#  index_servers_on_dokku_token  (dokku_token) UNIQUE
#  index_servers_on_org_id       (org_id)
#
# Foreign Keys
#
#  org_id  (org_id => orgs.id)
#
FactoryBot.define do
  factory :server do
    provider { "MyString" }
    name { "MyString" }
    dokku_token { "MyString" }
    status { "MyString" }
  end
end
