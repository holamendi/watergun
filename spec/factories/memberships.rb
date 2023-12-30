# == Schema Information
#
# Table name: memberships
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  org_id     :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_memberships_on_org_id              (org_id)
#  index_memberships_on_user_id             (user_id)
#  index_memberships_on_user_id_and_org_id  (user_id,org_id) UNIQUE
#
# Foreign Keys
#
#  org_id   (org_id => orgs.id)
#  user_id  (user_id => users.id)
#
FactoryBot.define do
  factory :membership do
    user { nil }
    org { nil }
  end
end
