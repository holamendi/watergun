class GithubRepo < ApplicationRecord
  include Remote

  belongs_to :account, default: -> { Current.account }
  belongs_to :app

  validates :repo, :branch, presence: true
end
