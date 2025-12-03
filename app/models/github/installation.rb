class Github::Installation < ApplicationRecord
  belongs_to :account

  belongs_to :github_app, class_name: "Github::App"
  has_many :events, class_name: "Github::Event"
end
