class Deployment < ApplicationRecord
  include ServerActionable
  has_paper_trail on: %i[create]

  belongs_to :org, default: -> { Current.org }
  belongs_to :app, touch: true

  store_attribute :data, :author_login, :string
  store_attribute :data, :author_url, :string
  store_attribute :data, :author_avatar_url, :string
  store_attribute :data, :author_date, :datetime
  store_attribute :data, :commit_message, :string
  store_attribute :data, :commit_html_url, :string

  str_enum :status, [:pending, :deploying, :success, :error], default: :pending

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

  def deploying!(at = Time.current)
    update!(status: :deploying, started_at: at)
  end

  def success!(at = Time.current)
    transaction do
      update!(status: :success, finished_at: at)
      app.touch(:deployed_at)
    end
  end

  def error!(at = Time.current)
    update!(status: :error, finished_at: at)
  end

  def duration
    return unless started_at && finished_at

    finished_at - started_at
  end
end
