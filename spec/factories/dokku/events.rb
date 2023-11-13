FactoryBot.define do
  factory :dokku_event, class: 'Dokku::Event' do
    server { nil }
    eventable { nil }
    membership { nil }
    command { "MyText" }
    status { "MyString" }
    job_id { "MyString" }
    completed_at { "2023-11-13 18:17:26" }
  end
end
