# == Schema Information
#
# Table name: orgs
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :org do
    name { "MyString" }
  end
end
