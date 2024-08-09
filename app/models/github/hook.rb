class Github::Hook < ApplicationRecord
  has_secure_token :token
  has_secure_token :secret

  belongs_to :account, default: -> { Current.account }
  belongs_to :github_repo, class_name: "Github::Repo"
  has_many :github_events, class_name: "Github::Event", foreign_key: :github_hook_id
end
