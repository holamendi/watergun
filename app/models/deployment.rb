class Deployment < ApplicationRecord
  include LogStreamable
  include ServerActionable

  belongs_to :account, default: -> { app.account }
  belongs_to :app
  belongs_to :user, default: -> { Current.user }, optional: true
  belongs_to :github_event, class_name: "Github::Event", optional: true

  store_attribute :data, :author_login, :string
  store_attribute :data, :author_url, :string
  store_attribute :data, :author_avatar_url, :string
  store_attribute :data, :author_date, :datetime
  store_attribute :data, :commit_message, :string
  store_attribute :data, :commit_html_url, :string

  enum :status, %w[pending deploying success error].index_by(&:itself), default: :pending
  enum :source, %w[web api_v1 github_webhook].index_by(&:itself)

  attribute :source, :string, default: -> { Current.source }

  scope :kept, -> { joins(:app).merge(App.kept) }
  scope :finished, -> { where.not(finished_at: nil) }

  delegate :github_repo, :server, to: :app

  before_validation on: :create do
    self.repo ||= github_repo.repo
  end

  broadcasts_to ->(deployment) { [deployment.app, :deployments] },
    partial: "projects/apps/deployments/deployment",
    target: "deployments",
    inserts_by: :prepend

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
