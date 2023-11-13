FactoryBot.define do
  factory :dokku_log, class: 'Dokku::Log' do
    org { nil }
    dokku_event { nil }
    content { "MyText" }
  end
end
