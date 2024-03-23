class GithubAccessToken < ApplicationRecord
  include BelongsToOrg

  validates :token, presence: true
end
