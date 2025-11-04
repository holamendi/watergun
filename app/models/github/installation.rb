class Github::Installation < ApplicationRecord
  belongs_to :account

  belongs_to :github_app, class_name: "Github::App"
end
