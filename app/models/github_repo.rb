class GithubRepo < ApplicationRecord
  include BelongsToOrg

  belongs_to :app, inverse_of: :github_repo

  validates :repo, :branch, presence: true
  validates :repo, format: {with: %r{\A[a-zA-Z0-9-]+/[a-zA-Z0-9-]+\z}}, allow_blank: true
  validate :validate_repo_exists, on: :create
  validate :validate_branch_exists

  before_create { self.private = @github_repo.private? }

  private

  def validate_repo_exists
    return if errors.where(:repo).any?

    @github_repo = Octokit.repo(repo)
  rescue Octokit::NotFound
    errors.add(:repo, "does not exist")
  end

  def validate_branch_exists
    return if errors.where(:repo).any? || errors.where(:branch).any?
    return unless branch_changed?

    Octokit.branch(repo, branch)
  rescue Octokit::NotFound
    errors.add(:branch, "does not exist")
  end
end
