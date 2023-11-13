FactoryBot.define do
  factory :dokku_user, class: 'Dokku::User' do
    org { nil }
    server { nil }
    private_key { "MyText" }
  end
end
