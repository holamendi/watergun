class GithubRepo < ApplicationRecord
  include BelongsToOrg

  belongs_to :app, inverse_of: :github_repo

  validates :repo, :branch, presence: true
  validates :repo, format: {with: %r{\A[a-zA-Z0-9-]+/[a-zA-Z0-9-]+\z}}, allow_blank: true
  validate :validate_repo_exists, on: :create
  validate :validate_branch_exists, if: :branch_changed?

  before_create { self.private = remote_repo.private? }

  def remote_repo
    @remote_repo ||= Octokit.repo(repo)
  rescue Octokit::NotFound
    nil
  end

  def remote_branch
    Octokit.branch(repo, branch)
  rescue Octokit::NotFound
    nil
  end

  def remote_commit(sha)
    Octokit.commit(repo, sha)
  rescue Octokit::UnprocessableEntity
    nil
  end

  private

  def validate_repo_exists
    return if errors.where(:repo).any?
    return if remote_repo

    errors.add(:repo, "does not exist")
  end

  def validate_branch_exists
    return if errors.where(:repo).any? || errors.where(:branch).any?
    return if remote_branch

    errors.add(:branch, "does not exist")
  end
end
