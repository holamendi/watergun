class Deployment < ApplicationRecord
  has_paper_trail on: %i[create]

  include BelongsToOrg
  include ServerActionable

  belongs_to :app

  enum status: {
    queued: "queued",
    in_progress: "in_progress",
    success: "success",
    failure: "failure"
  }, _default: "queued"

  enum source: {
    web: "web",
    api_v1: "api_v1"
  }

  scope :kept, -> { joins(:app).merge(App.kept) }

  delegate :github_repo, to: :app

  before_validation on: :create do
    self.repo ||= github_repo.repo
  end

  def in_progress!(at = Time.current)
    update!(status: :in_progress, started_at: at)
  end

  def success!(at = Time.current)
    update!(status: :success, finished_at: at)
  end

  def failure!(at = Time.current)
    update!(status: :failure, finished_at: at)
  end
end
