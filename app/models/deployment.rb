class Deployment < ApplicationRecord
  include BelongsToOrg
  include ServerActionable

  belongs_to :app

  delegate :github_repo, to: :app

  before_validation on: :create do
    self.repo ||= github_repo.repo
    self.branch ||= github_repo.branch
  end
end
