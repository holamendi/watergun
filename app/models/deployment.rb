class Deployment < ApplicationRecord
  include ServerActionable
  has_paper_trail on: %i[create]

  belongs_to :org, default: -> { Current.org }
  belongs_to :app, touch: true

  enum status: {
    queued: 0,
    in_progress: 1,
    success: 2,
    failure: 3
  }, _default: :queued

  enum source: {
    web: 0,
    api_v1: 1
  }

  scope :kept, -> { joins(:app).merge(App.kept) }
  scope :finished, -> { where.not(finished_at: nil) }

  delegate :github_repo, to: :app

  before_validation on: :create do
    self.repo ||= github_repo.repo
  end

  def server_action
    server_actions.last
  end

  def short_sha
    sha&.first(7)
  end

  def finished?
    finished_at.present?
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

  def duration
    return unless started_at && finished_at

    finished_at - started_at
  end
end
