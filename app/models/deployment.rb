class Deployment < ApplicationRecord
  include LogStreamable
  include ServerActionable

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true
  belongs_to :user, default: -> { Current.user }
  belongs_to :github_event, class_name: "Github::Event", optional: true

  has_one :server_action, as: :actionable, dependent: :destroy

  store_attribute :data, :author_login, :string
  store_attribute :data, :author_url, :string
  store_attribute :data, :author_avatar_url, :string
  store_attribute :data, :author_date, :datetime
  store_attribute :data, :commit_message, :string
  store_attribute :data, :commit_html_url, :string

  str_enum :status, [:pending, :deploying, :success, :error], default: :pending
  str_enum :source, [:web, :api_v1, :github_webhook]

  attribute :source, :string, default: -> { Current.source }

  scope :kept, -> { joins(:app).merge(App.kept) }
  scope :finished, -> { where.not(finished_at: nil) }

  delegate :github_repo, to: :app

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
