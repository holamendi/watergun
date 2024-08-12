class Github::Repo < ApplicationRecord
  belongs_to :account, default: -> { Current.account }
  belongs_to :app

  scope :kept, -> { joins(:app).merge(App.kept) }

  validates :repo, :branch, presence: true
  validate :validate_remote_repo_exists, if: :repo_changed?
  validate :validate_remote_branch_exists, if: :branch_changed?

  before_create { self.private = remote_repo.private? }

  delegate :github_integration, to: :account

  def web_url
    "https://github.com/#{repo}/tree/#{branch}"
  end

  def remote_repo
    github_integration.api_client.repo(repo)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  def remote_branch
    github_integration.api_client.branch(repo, branch)
  rescue Octokit::NotFound
    nil
  end

  def remote_commit(sha)
    github_integration.api_client.commit(repo, sha)
  rescue Octokit::UnprocessableEntity
    nil
  end

  private

  def validate_remote_repo_exists
    return if errors.where(:repo).present?

    errors.add(:repo, "does not exist") unless remote_repo
  end

  def validate_remote_branch_exists
    return if errors.where(:repo).present? || errors.where(:branch).present?

    errors.add(:branch, "does not exist") unless remote_branch
  end
end
