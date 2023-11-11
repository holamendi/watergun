FactoryBot.define do
  factory :session do
    user { nil }
    token { "MyString" }
    expires_at { "2023-11-11 20:20:20" }
  end
end
