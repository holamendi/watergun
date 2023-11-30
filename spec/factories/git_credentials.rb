FactoryBot.define do
  factory :git_credential do
    org { nil }
    provider { "MyString" }
    personal_access_token { "MyString" }
  end
end
