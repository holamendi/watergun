class Deployment < ApplicationRecord
  include BelongsToOrg
  include ServerActionable

  belongs_to :app

  enum status: {
    scheduled: "scheduled",
    in_progress: "in_progress",
    success: "success",
    failure: "failure"
  }, _default: "scheduled"

  delegate :github_repo, to: :app

  before_validation on: :create do
    self.repo ||= github_repo.repo
  end
end
