class GithubRepo < ApplicationRecord
  include BelongsToOrg

  belongs_to :app

  attribute :private, :boolean, default: false

  validates :repo, :branch, presence: true
  validates :repo, format: {with: %r{\A[a-zA-Z0-9-]+/[a-zA-Z0-9-]+\z}}
end
